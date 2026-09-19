import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/analytics/data/models/watch_event_model.dart';
import 'package:truthworld/features/analytics/data/services/geolocation_service.dart';

/// Static helper utilities for creator analytics formatting, color palettes,
/// traffic taxonomy labels, and geographic coordinates.
class CreatorGeoTaxonomyHelper {
  CreatorGeoTaxonomyHelper._();

  /// Format seconds into readable duration string
  static String formatSeconds(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m ${secs}s';
    return '${secs}s';
  }

  /// Format traffic source key into human-friendly label
  static String formatSourceLabel(String key) {
    // Use the hierarchical taxonomy enum for clean labels
    final category = TrafficSourceCategory.fromKey(key);
    if (category != TrafficSourceCategory.unknown) return category.label;

    // Fallback for any missed keys
    return key.replaceAll('_', ' ').capitalize ?? key;
  }

  /// Get traffic source type (internal vs external) for grouping
  static TrafficSourceType getSourceType(String key) {
    return TrafficSourceCategory.fromKey(key).type;
  }

  /// Generate a list of distinct colors for categorical charts
  static List<int> generateColors(int count) {
    const base = [
      0xFF3B82F6,
      0xFF22C55E,
      0xFFF97316,
      0xFFEF4444,
      0xFF8B5CF6,
      0xFF06B6D4,
      0xFFEC4899,
      0xFFEAB308,
      0xFF64748B,
      0xFF14B8A6,
    ];
    if (count <= base.length) {
      return base.sublist(0, count.clamp(0, base.length));
    }
    final extra = <int>[];
    for (var i = base.length; i < count; i++) {
      final hue = i * 360 ~/ count;
      extra.add(
        HSVColor.fromAHSV(1, hue.toDouble(), 0.7, 0.8).toColor().toARGB32(),
      );
    }
    return [...base, ...extra];
  }

  /// Resolve Indian state name from code
  static String getStateName(
    String stateCode,
    GeolocationService geolocationService,
  ) {
    return geolocationService.getAllIndianStates().firstWhere(
      (s) => s.startsWith(stateCode),
      orElse: () => stateCode,
    );
  }

  /// Get geographic coordinates [lat, lng] for states or countries
  static List<double>? getCoordinates(String name) {
    final cleanName = name.trim();
    if (_geoCoordinates.containsKey(cleanName)) {
      return _geoCoordinates[cleanName];
    }
    final lowerName = cleanName.toLowerCase();
    for (final entry in _geoCoordinates.entries) {
      if (entry.key.toLowerCase() == lowerName) {
        return entry.value;
      }
    }
    return null;
  }

  static const Map<String, List<double>> _geoCoordinates = {
    // Indian States/UTs
    'Andaman and Nicobar': [11.74, 92.65],
    'Andhra Pradesh': [15.97, 79.74],
    'Arunachal Pradesh': [28.21, 94.72],
    'Assam': [26.20, 92.93],
    'Bihar': [25.09, 85.31],
    'Chandigarh': [30.73, 76.77],
    'Chhattisgarh': [21.27, 81.86],
    'Dadra and Nagar Haveli': [20.18, 73.01],
    'Daman and Diu': [20.42, 72.83],
    'Delhi': [28.61, 77.20],
    'Goa': [15.29, 74.12],
    'Gujarat': [22.25, 71.19],
    'Haryana': [29.05, 76.08],
    'Himachal Pradesh': [31.10, 77.17],
    'Jammu and Kashmir': [33.77, 76.57],
    'Jharkhand': [23.61, 85.27],
    'Karnataka': [15.31, 75.71],
    'Kerala': [10.85, 76.27],
    'Ladakh': [34.15, 77.57],
    'Lakshadweep': [10.57, 72.64],
    'Madhya Pradesh': [22.97, 78.65],
    'Maharashtra': [19.75, 75.71],
    'Manipur': [24.66, 93.90],
    'Meghalaya': [25.46, 91.36],
    'Mizoram': [23.16, 92.93],
    'Nagaland': [26.15, 94.56],
    'Odisha': [20.95, 85.09],
    'Puducherry': [11.94, 79.80],
    'Punjab': [31.14, 75.34],
    'Rajasthan': [27.02, 74.21],
    'Sikkim': [27.53, 88.51],
    'Tamil Nadu': [11.12, 78.65],
    'Telangana': [18.11, 79.01],
    'Tripura': [23.94, 91.98],
    'Uttar Pradesh': [26.84, 80.88],
    'Uttarakhand': [30.06, 79.01],
    'West Bengal': [22.98, 87.85],

    // Countries
    'India': [20.59, 78.96],
    'IN': [20.59, 78.96],
    'United States': [37.09, -95.71],
    'US': [37.09, -95.71],
    'United Kingdom': [55.37, -3.43],
    'UK': [55.37, -3.43],
    'Canada': [56.13, -106.34],
    'CA': [56.13, -106.34],
    'Australia': [-25.27, 133.77],
    'AU': [-25.27, 133.77],
    'Germany': [51.16, 10.45],
    'DE': [51.16, 10.45],
    'France': [46.22, 2.21],
    'FR': [46.22, 2.21],
    'Japan': [36.20, 138.25],
    'JP': [36.20, 138.25],
    'China': [35.86, 104.19],
    'CN': [35.86, 104.19],
    'Brazil': [-14.23, -51.92],
    'BR': [-14.23, -51.92],
    'Russia': [61.52, 105.31],
    'RU': [61.52, 105.31],
    'Singapore': [1.35, 103.81],
    'SG': [1.35, 103.81],
    'United Arab Emirates': [23.42, 53.84],
    'AE': [23.42, 53.84],
  };
}
