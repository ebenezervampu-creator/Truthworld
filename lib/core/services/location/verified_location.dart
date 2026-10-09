import 'package:flutter/foundation.dart';

/// Enumeration of valid residential and administrative locality types.
enum LocalityType {
  city,
  town,
  village,
  hamlet,
  municipality,
  district,
  suburb,
  unknown;

  static LocalityType fromString(String? typeStr) {
    if (typeStr == null) return LocalityType.unknown;
    final lower = typeStr.trim().toLowerCase();
    if (lower.contains('city') || lower == 'pplc' || lower == 'ppla') {
      return LocalityType.city;
    }
    if (lower.contains('town') || lower == 'ppla2' || lower == 'ppla3') {
      return LocalityType.town;
    }
    if (lower.contains('village') || lower == 'ppl' || lower == 'settlement') {
      return LocalityType.village;
    }
    if (lower.contains('hamlet')) {
      return LocalityType.hamlet;
    }
    if (lower.contains('municipality')) {
      return LocalityType.municipality;
    }
    if (lower.contains('suburb') || lower.contains('neighbourhood') || lower == 'pplx') {
      return LocalityType.suburb;
    }
    if (lower.contains('district') || lower.contains('county')) {
      return LocalityType.district;
    }
    return LocalityType.unknown;
  }

  String get displayName {
    switch (this) {
      case LocalityType.city:
        return 'City';
      case LocalityType.town:
        return 'Town';
      case LocalityType.village:
        return 'Village';
      case LocalityType.hamlet:
        return 'Hamlet';
      case LocalityType.municipality:
        return 'Municipality';
      case LocalityType.suburb:
        return 'Suburb';
      case LocalityType.district:
        return 'District';
      case LocalityType.unknown:
        return 'Locality';
    }
  }
}

/// Represents an authentic, verified geographic settlement (city, town, or village).
@immutable
class VerifiedLocation {
  const VerifiedLocation({
    required this.name,
    required this.localityType,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.formattedAddress,
    this.state,
    this.county,
    this.countryCode = '',
    this.isVerified = true,
  });

  final String name;
  final LocalityType localityType;
  final String? state;
  final String? county;
  final String country;
  final String countryCode;
  final double latitude;
  final double longitude;
  final String formattedAddress;
  final bool isVerified;

  String get typeLabel => localityType.displayName;

  /// Creates a [VerifiedLocation] from a Photon (Komoot/OSM) GeoJSON feature.
  factory VerifiedLocation.fromPhotonFeature(Map<String, dynamic> feature) {
    final props = (feature['properties'] as Map<String, dynamic>?) ?? {};
    final geometry = (feature['geometry'] as Map<String, dynamic>?) ?? {};
    final coordinates = (geometry['coordinates'] as List<dynamic>?) ?? [0.0, 0.0];

    final lon = (coordinates.isNotEmpty ? (coordinates[0] as num).toDouble() : 0.0);
    final lat = (coordinates.length > 1 ? (coordinates[1] as num).toDouble() : 0.0);

    final rawName = props['name'] as String? ??
        props['city'] as String? ??
        props['town'] as String? ??
        props['village'] as String? ??
        props['locality'] as String? ??
        '';

    final osmValue = props['osm_value'] as String? ?? '';
    final typeProp = props['type'] as String? ?? '';
    final localityType = LocalityType.fromString('$osmValue $typeProp');

    final state = props['state'] as String?;
    final county = props['county'] as String? ?? props['district'] as String?;
    final country = props['country'] as String? ?? '';
    final countryCode = props['countrycode'] as String? ?? '';

    final addressParts = <String>[];
    if (rawName.isNotEmpty) addressParts.add(rawName);
    if (county != null && county.isNotEmpty && county != rawName) {
      addressParts.add(county);
    }
    if (state != null && state.isNotEmpty && state != rawName) {
      addressParts.add(state);
    }
    if (country.isNotEmpty && country != rawName) {
      addressParts.add(country);
    }

    final formatted = addressParts.isNotEmpty ? addressParts.join(', ') : rawName;

    return VerifiedLocation(
      name: rawName,
      localityType: localityType,
      state: state,
      county: county,
      country: country,
      countryCode: countryCode.toUpperCase(),
      latitude: lat,
      longitude: lon,
      formattedAddress: formatted,
    );
  }

  /// Creates a [VerifiedLocation] from an Open-Meteo Geocoding result item.
  factory VerifiedLocation.fromOpenMeteoResult(Map<String, dynamic> item) {
    final rawName = item['name'] as String? ?? '';
    final lat = (item['latitude'] as num?)?.toDouble() ?? 0.0;
    final lon = (item['longitude'] as num?)?.toDouble() ?? 0.0;
    final featureCode = item['feature_code'] as String? ?? '';
    final localityType = LocalityType.fromString(featureCode);

    final country = item['country'] as String? ?? '';
    final countryCode = item['country_code'] as String? ?? '';
    final state = item['admin1'] as String?;
    final county = item['admin2'] as String?;

    final addressParts = <String>[];
    if (rawName.isNotEmpty) addressParts.add(rawName);
    if (county != null && county.isNotEmpty && county != rawName) {
      addressParts.add(county);
    }
    if (state != null && state.isNotEmpty && state != rawName) {
      addressParts.add(state);
    }
    if (country.isNotEmpty && country != rawName) {
      addressParts.add(country);
    }

    final formatted = addressParts.isNotEmpty ? addressParts.join(', ') : rawName;

    return VerifiedLocation(
      name: rawName,
      localityType: localityType,
      state: state,
      county: county,
      country: country,
      countryCode: countryCode.toUpperCase(),
      latitude: lat,
      longitude: lon,
      formattedAddress: formatted,
    );
  }

  /// Creates a [VerifiedLocation] from BigDataCloud reverse geocode response.
  factory VerifiedLocation.fromBigDataCloud(Map<String, dynamic> json) {
    final rawName = json['city'] as String? ??
        json['locality'] as String? ??
        json['principalSubdivision'] as String? ??
        '';

    final lat = (json['latitude'] as num?)?.toDouble() ?? 0.0;
    final lon = (json['longitude'] as num?)?.toDouble() ?? 0.0;
    final state = json['principalSubdivision'] as String?;
    final country = json['countryName'] as String? ?? '';
    final countryCode = json['countryCode'] as String? ?? '';

    final addressParts = <String>[];
    if (rawName.isNotEmpty) addressParts.add(rawName);
    if (state != null && state.isNotEmpty && state != rawName) {
      addressParts.add(state);
    }
    if (country.isNotEmpty && country != rawName) {
      addressParts.add(country);
    }

    return VerifiedLocation(
      name: rawName,
      localityType: LocalityType.city,
      state: state,
      country: country,
      countryCode: countryCode.toUpperCase(),
      latitude: lat,
      longitude: lon,
      formattedAddress: addressParts.join(', '),
    );
  }

  /// Creates a [VerifiedLocation] from OpenStreetMap Nominatim JSON.
  factory VerifiedLocation.fromNominatim(Map<String, dynamic> json) {
    final address = (json['address'] as Map<String, dynamic>?) ?? {};
    final rawName = address['city'] as String? ??
        address['town'] as String? ??
        address['village'] as String? ??
        address['municipality'] as String? ??
        address['suburb'] as String? ??
        address['county'] as String? ??
        (json['name'] as String? ?? '');

    final lat = double.tryParse(json['lat']?.toString() ?? '0') ?? 0.0;
    final lon = double.tryParse(json['lon']?.toString() ?? '0') ?? 0.0;

    final typeStr = json['type'] as String? ??
        json['addresstype'] as String? ??
        (address['city'] != null ? 'city' : (address['town'] != null ? 'town' : 'village'));
    final localityType = LocalityType.fromString(typeStr);

    final state = address['state'] as String?;
    final county = address['county'] as String?;
    final country = address['country'] as String? ?? '';
    final countryCode = address['country_code'] as String? ?? '';

    final addressParts = <String>[];
    if (rawName.isNotEmpty) addressParts.add(rawName);
    if (county != null && county.isNotEmpty && county != rawName) {
      addressParts.add(county);
    }
    if (state != null && state.isNotEmpty && state != rawName) {
      addressParts.add(state);
    }
    if (country.isNotEmpty && country != rawName) {
      addressParts.add(country);
    }

    return VerifiedLocation(
      name: rawName,
      localityType: localityType,
      state: state,
      county: county,
      country: country,
      countryCode: countryCode.toUpperCase(),
      latitude: lat,
      longitude: lon,
      formattedAddress: addressParts.isNotEmpty ? addressParts.join(', ') : rawName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'localityType': localityType.name,
      'state': state,
      'county': county,
      'country': country,
      'countryCode': countryCode,
      'latitude': latitude,
      'longitude': longitude,
      'formattedAddress': formattedAddress,
      'isVerified': isVerified,
    };
  }

  factory VerifiedLocation.fromMap(Map<String, dynamic> map) {
    return VerifiedLocation(
      name: map['name'] as String? ?? '',
      localityType: LocalityType.fromString(map['localityType'] as String?),
      state: map['state'] as String?,
      county: map['county'] as String?,
      country: map['country'] as String? ?? '',
      countryCode: map['countryCode'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      formattedAddress: map['formattedAddress'] as String? ?? '',
      isVerified: map['isVerified'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VerifiedLocation &&
        other.formattedAddress == formattedAddress &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => Object.hash(formattedAddress, latitude, longitude);
}
