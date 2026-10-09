import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/location/verified_location.dart';

/// Target parsed from a coordinates string or Google Maps share link.
class ParsedMapTarget {
  const ParsedMapTarget({
    this.latitude,
    this.longitude,
    this.query,
  });

  final double? latitude;
  final double? longitude;
  final String? query;

  bool get hasCoordinates => latitude != null && longitude != null;
  bool get hasQuery => query != null && query!.trim().isNotEmpty;
}

/// Authoritative service for verifying, searching, and reverse-geocoding
/// residential localities (towns, cities, villages) worldwide.
class LocationLookupService {
  LocationLookupService._();

  static const String _userAgent = 'TruthWorld-App/1.0 (contact@truthworld.in)';
  static const Duration _timeout = Duration(seconds: 7);

  /// Searches for authentic towns, cities, and villages matching [query].
  /// Returns an empty list if no valid settlements match or if input is random.
  static Future<List<VerifiedLocation>> searchSettlements(
    String query, {
    int limit = 8,
  }) async {
    final clean = query.trim();
    if (clean.length < 2) return [];

    // Tier 1: Photon OpenStreetMap Geocoder (Settlement-tagged)
    try {
      final photonUri = Uri.parse(
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(clean)}'
        '&limit=$limit'
        '&osm_tag=place:city'
        '&osm_tag=place:town'
        '&osm_tag=place:village'
        '&osm_tag=place:hamlet'
        '&osm_tag=place:municipality'
        '&osm_tag=place:suburb'
        '&osm_tag=place:district',
      );

      final response = await http
          .get(photonUri, headers: {'User-Agent': _userAgent})
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final features = (data['features'] as List<dynamic>?) ?? [];

        final results = <VerifiedLocation>[];
        final seen = <String>{};

        for (final item in features) {
          if (item is Map<String, dynamic>) {
            final loc = VerifiedLocation.fromPhotonFeature(item);
            if (loc.name.isNotEmpty && loc.country.isNotEmpty) {
              final key = '${loc.name.toLowerCase()}_${loc.country.toLowerCase()}';
              if (!seen.contains(key)) {
                seen.add(key);
                results.add(loc);
              }
            }
          }
        }

        if (results.isNotEmpty) {
          return results;
        }
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'LocationLookupService.searchSettlements.photon',
      );
    }

    // Tier 2: Open-Meteo Global Settlement Geocoder
    try {
      final meteoUri = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search?'
        'name=${Uri.encodeComponent(clean)}'
        '&count=$limit'
        '&language=en'
        '&format=json',
      );

      final response = await http
          .get(meteoUri, headers: {'User-Agent': _userAgent})
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final resultsRaw = (data['results'] as List<dynamic>?) ?? [];

        final results = <VerifiedLocation>[];
        for (final item in resultsRaw) {
          if (item is Map<String, dynamic>) {
            final loc = VerifiedLocation.fromOpenMeteoResult(item);
            if (loc.name.isNotEmpty && loc.country.isNotEmpty) {
              results.add(loc);
            }
          }
        }

        if (results.isNotEmpty) {
          return results;
        }
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'LocationLookupService.searchSettlements.openMeteo',
      );
    }

    return [];
  }

  /// Reverse-geocodes coordinates to the nearest authentic town, city, or village.
  /// Returns null if the pin is in an uninhabited wilderness or water body.
  static Future<VerifiedLocation?> reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      return null;
    }

    // 1. Photon Reverse Geocoding
    try {
      final uri = Uri.parse(
        'https://photon.komoot.io/reverse?lat=$latitude&lon=$longitude',
      );
      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final features = (data['features'] as List<dynamic>?) ?? [];
        if (features.isNotEmpty) {
          final first = features.first as Map<String, dynamic>;
          final loc = VerifiedLocation.fromPhotonFeature(first);
          if (loc.name.isNotEmpty && loc.country.isNotEmpty) {
            return loc;
          }
        }
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'LocationLookupService.reverseGeocode.photon',
      );
    }

    // 2. BigDataCloud Reverse Geocoding fallback
    try {
      final bdcUri = Uri.parse(
        'https://api.bigdatacloud.net/data/reverse-geocode-client?'
        'latitude=$latitude&longitude=$longitude&localityLanguage=en',
      );
      final response = await http
          .get(bdcUri, headers: {'User-Agent': _userAgent})
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final city = data['city'] as String? ?? '';
        final locality = data['locality'] as String? ?? '';
        if (city.isNotEmpty || locality.isNotEmpty) {
          final loc = VerifiedLocation.fromBigDataCloud(data);
          if (loc.name.isNotEmpty && loc.country.isNotEmpty) {
            return loc;
          }
        }
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'LocationLookupService.reverseGeocode.bigDataCloud',
      );
    }

    // 3. OpenStreetMap Nominatim Reverse Geocoding fallback
    try {
      final nomUri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?'
        'lat=$latitude&lon=$longitude&format=json&addressdetails=1',
      );
      final response = await http
          .get(nomUri, headers: {'User-Agent': _userAgent})
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address = (data['address'] as Map<String, dynamic>?) ?? {};
        final name = address['city'] ?? address['town'] ?? address['village'] ?? address['municipality'];
        if (name != null && name.toString().trim().isNotEmpty) {
          final loc = VerifiedLocation.fromNominatim(data);
          if (loc.name.isNotEmpty && loc.country.isNotEmpty) {
            return loc;
          }
        }
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'LocationLookupService.reverseGeocode.nominatim',
      );
    }

    return null;
  }

  /// Validates an arbitrary location string against global geocoding records.
  /// If the string corresponds to an authentic town, city, or village, returns
  /// the resolved [VerifiedLocation]. If random/invalid, returns null.
  static Future<VerifiedLocation?> validateLocationString(String input) async {
    final clean = input.trim();
    if (clean.length < 2) return null;

    final results = await searchSettlements(clean, limit: 6);
    if (results.isEmpty) return null;

    final inputLower = clean.toLowerCase();

    // Check for exact name or formatted address match
    for (final loc in results) {
      final nameLower = loc.name.toLowerCase();
      final addrLower = loc.formattedAddress.toLowerCase();
      if (nameLower == inputLower || addrLower == inputLower) {
        return loc;
      }
    }

    // Check if input starts with or is contained in the primary place name
    for (final loc in results) {
      final nameLower = loc.name.toLowerCase();
      if (inputLower.startsWith(nameLower) || nameLower.startsWith(inputLower)) {
        return loc;
      }
    }

    // If query returned confident results, return the top candidate
    return results.first;
  }

  /// Detects the user's current city/town/village using HTTPS IP geolocation
  /// and authoritative reverse-geocoding.
  static Future<VerifiedLocation?> detectCurrentLocation() async {
    // 1. Query freeipapi.com over HTTPS
    try {
      final uri = Uri.parse('https://freeipapi.com/api/json');
      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final lat = (data['latitude'] as num?)?.toDouble();
        final lon = (data['longitude'] as num?)?.toDouble();

        if (lat != null && lon != null) {
          final resolved = await reverseGeocode(lat, lon);
          if (resolved != null) return resolved;
        }

        final city = data['cityName'] as String? ?? '';
        final country = data['countryName'] as String? ?? '';
        if (city.isNotEmpty && country.isNotEmpty) {
          return validateLocationString('$city, $country');
        }
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'LocationLookupService.detectCurrentLocation.freeipapi',
      );
    }

    // 2. Query ipwho.is over HTTPS as secondary fallback (100% free, no key required)
    try {
      final uri = Uri.parse('https://ipwho.is/');
      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final lat = (data['latitude'] as num?)?.toDouble();
          final lon = (data['longitude'] as num?)?.toDouble();

          if (lat != null && lon != null) {
            final resolved = await reverseGeocode(lat, lon);
            if (resolved != null) return resolved;
          }

          final city = data['city'] as String? ?? '';
          final country = data['country'] as String? ?? '';
          if (city.isNotEmpty && country.isNotEmpty) {
            return validateLocationString('$city, $country');
          }
        }
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'LocationLookupService.detectCurrentLocation.ipwhois',
      );
    }

    return null;
  }

  /// Parses latitude/longitude coordinates or Google Maps share links.
  static ParsedMapTarget? parseGoogleMapsUrlOrCoordinates(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    // Pattern 1: Raw "lat, lon" (e.g. "37.7749, -122.4194" or "12.9716, 77.5946")
    final coordRegExp = RegExp(
      r'^\s*([+-]?\d+(?:\.\d+)?)\s*,\s*([+-]?\d+(?:\.\d+)?)\s*$',
    );
    final coordMatch = coordRegExp.firstMatch(trimmed);
    if (coordMatch != null) {
      final lat = double.tryParse(coordMatch.group(1)!);
      final lon = double.tryParse(coordMatch.group(2)!);
      if (lat != null && lon != null) {
        return ParsedMapTarget(latitude: lat, longitude: lon);
      }
    }

    // Pattern 2: Google Maps URL with @lat,lon,zoom parameter
    // e.g. https://www.google.com/maps/place/.../@37.774929,-122.419416,15z/...
    final atMatch = RegExp(r'@([+-]?\d+\.\d+),([+-]?\d+\.\d+)').firstMatch(trimmed);
    if (atMatch != null) {
      final lat = double.tryParse(atMatch.group(1)!);
      final lon = double.tryParse(atMatch.group(2)!);
      if (lat != null && lon != null) {
        return ParsedMapTarget(latitude: lat, longitude: lon);
      }
    }

    // Pattern 3: Google Maps query parameter (?q=lat,lon or ?q=Town+Name)
    try {
      final uri = Uri.tryParse(trimmed);
      if (uri != null) {
        final qParam = uri.queryParameters['q'] ??
            uri.queryParameters['query'] ??
            uri.queryParameters['destination'] ??
            uri.queryParameters['ll'];

        if (qParam != null && qParam.isNotEmpty) {
          final qCoordMatch = coordRegExp.firstMatch(qParam);
          if (qCoordMatch != null) {
            final lat = double.tryParse(qCoordMatch.group(1)!);
            final lon = double.tryParse(qCoordMatch.group(2)!);
            if (lat != null && lon != null) {
              return ParsedMapTarget(latitude: lat, longitude: lon);
            }
          }
          return ParsedMapTarget(query: qParam);
        }
      }
    } catch (_) {}

    return null;
  }
}
