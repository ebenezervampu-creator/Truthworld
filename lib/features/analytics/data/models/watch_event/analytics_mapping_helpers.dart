/// Serialization and mapping helpers for analytics models.
Map<String, int> castIntMap(dynamic source) {
  if (source == null) return {};
  if (source is Map<String, dynamic>) {
    return source.map((k, v) => MapEntry(k, (v as num).toInt()));
  }
  return {};
}

Map<String, double> castDoubleMap(dynamic source) {
  if (source == null) return {};
  if (source is Map<String, dynamic>) {
    return source.map((k, v) => MapEntry(k, (v as num).toDouble()));
  }
  return {};
}

Map<DateTime, int> castDateIntMap(dynamic source) {
  if (source == null) return {};
  if (source is Map<String, dynamic>) {
    return source.map(
      (k, v) => MapEntry(DateTime.parse(k), (v as num).toInt()),
    );
  }
  return {};
}

Map<String, int> mergeMaps(Map<String, int> a, Map<String, int> b) {
  final result = Map<String, int>.from(a);
  for (final entry in b.entries) {
    result[entry.key] = (result[entry.key] ?? 0) + entry.value;
  }
  return result;
}

/// Geographic region mapping data model.
class GeoRegionModel {
  const GeoRegionModel({
    required this.regionKey,
    required this.count,
    required this.isIndianState,
  });

  factory GeoRegionModel.fromMap(Map<String, dynamic> map) => GeoRegionModel(
    regionKey: map['regionKey'] as String? ?? '',
    count: (map['count'] as num?)?.toInt() ?? 0,
    isIndianState: map['isIndianState'] as bool? ?? false,
  );

  final String regionKey;
  final int count;
  final bool isIndianState;

  Map<String, dynamic> toMap() => {
    'regionKey': regionKey,
    'count': count,
    'isIndianState': isIndianState,
  };
}

/// Audience retention funnel analysis model.
class RetentionFunnelModel {
  const RetentionFunnelModel({
    required this.impressions,
    required this.start,
    required this.dropOnStart,
    required this.d25,
    required this.d50,
    required this.d75,
    required this.d100,
    required this.startRate,
    required this.dropOnStartRate,
    required this.completionRate,
  });

  factory RetentionFunnelModel.fromMap(Map<String, dynamic> map) =>
      RetentionFunnelModel(
        impressions: (map['impressions'] as num?)?.toInt() ?? 0,
        start: (map['start'] as num?)?.toInt() ?? 0,
        dropOnStart: (map['dropOnStart'] as num?)?.toInt() ?? 0,
        d25: (map['d25'] as num?)?.toInt() ?? 0,
        d50: (map['d50'] as num?)?.toInt() ?? 0,
        d75: (map['d75'] as num?)?.toInt() ?? 0,
        d100: (map['d100'] as num?)?.toInt() ?? 0,
        startRate: (map['startRate'] as num?)?.toDouble() ?? 0.0,
        dropOnStartRate: (map['dropOnStartRate'] as num?)?.toDouble() ?? 0.0,
        completionRate: (map['completionRate'] as num?)?.toDouble() ?? 0.0,
      );

  final int impressions;
  final int start;
  final int dropOnStart;
  final int d25;
  final int d50;
  final int d75;
  final int d100;
  final double startRate;
  final double dropOnStartRate;
  final double completionRate;

  Map<String, dynamic> toMap() => {
    'impressions': impressions,
    'start': start,
    'dropOnStart': dropOnStart,
    'd25': d25,
    'd50': d50,
    'd75': d75,
    'd100': d100,
    'startRate': startRate,
    'dropOnStartRate': dropOnStartRate,
    'completionRate': completionRate,
  };
}
