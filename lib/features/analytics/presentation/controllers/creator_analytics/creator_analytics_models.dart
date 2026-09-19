// Models representing chart and insight breakdown metrics for Creator Analytics.

class PieChartDataModel {
  PieChartDataModel({
    required this.title,
    required this.value,
    required this.percentage,
    required this.color,
  });

  final String title;
  final double value;
  final double percentage;
  final int color;
}

class BarChartDataModel {
  BarChartDataModel({
    required this.label,
    required this.value,
    required this.percentage,
    required this.color,
  });

  final String label;
  final double value;
  final double percentage;
  final int color;
}

class StateTrafficStat {
  StateTrafficStat({
    required this.stateName,
    required this.viewCount,
    required this.percentage,
  });

  final String stateName;
  final int viewCount;
  final double percentage;
}

class CountryTrafficStat {
  CountryTrafficStat({
    required this.countryName,
    required this.viewCount,
    required this.percentage,
  });

  final String countryName;
  final int viewCount;
  final double percentage;
}

class CityTrafficStat {
  CityTrafficStat({
    required this.cityName,
    required this.viewCount,
    required this.percentage,
  });

  final String cityName;
  final int viewCount;
  final double percentage;
}

class DeviceStatStat {
  DeviceStatStat({
    required this.deviceType,
    required this.count,
    required this.percentage,
  });

  final String deviceType;
  final int count;
  final double percentage;
}

class QualityStatStat {
  QualityStatStat({
    required this.quality,
    required this.count,
    required this.percentage,
  });

  final String quality;
  final int count;
  final double percentage;
}

class TrafficSourceStat {
  TrafficSourceStat({
    required this.source,
    required this.sourceKey,
    required this.count,
    required this.percentage,
  });

  final String source;
  final String sourceKey;
  final int count;
  final double percentage;
}

class WatchTimeTrendModel {
  WatchTimeTrendModel({
    required this.date,
    required this.watchTimeHours,
  });

  final DateTime date;
  final double watchTimeHours;
}

class ViewsTrendModel {
  ViewsTrendModel({
    required this.date,
    required this.views,
  });

  final DateTime date;
  final int views;
}

class SubscribersTrendModel {
  SubscribersTrendModel({
    required this.date,
    required this.subscribers,
  });

  final DateTime date;
  final int subscribers;
}
