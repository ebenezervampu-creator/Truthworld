class DownloadSettings {
  const DownloadSettings({
    this.wifiOnly = true,
    this.chargingRequired = false,
    this.deviceIdleRequired = false,
    this.minBatteryThresholdPercent = 20,
    this.downloadQuality = 'Ask each time',
    this.smartDownloadsEnabled = false,
    this.maxStorageLimit = '5GB',
    this.downloadLocation = 'Automatic',
    this.maxConcurrentDownloads = 2,
  });

  factory DownloadSettings.fromJson(Map<String, dynamic> json) {
    return DownloadSettings(
      wifiOnly: json['wifiOnly'] as bool? ?? true,
      chargingRequired: json['chargingRequired'] as bool? ?? false,
      deviceIdleRequired: json['deviceIdleRequired'] as bool? ?? false,
      minBatteryThresholdPercent:
          json['minBatteryThresholdPercent'] as int? ?? 20,
      downloadQuality: json['downloadQuality'] as String? ?? 'Ask each time',
      smartDownloadsEnabled: json['smartDownloadsEnabled'] as bool? ?? false,
      maxStorageLimit: json['maxStorageLimit'] as String? ?? '5GB',
      downloadLocation: json['downloadLocation'] as String? ?? 'Automatic',
      maxConcurrentDownloads: json['maxConcurrentDownloads'] as int? ?? 2,
    );
  }
  final bool wifiOnly;
  final bool chargingRequired;
  final bool deviceIdleRequired;
  final int minBatteryThresholdPercent; // e.g. 20%
  final String downloadQuality; // 'High (1080p)', 'Medium (720p)', 'Low (480p)'

  // Smart Downloads
  final bool smartDownloadsEnabled;
  final String
  maxStorageLimit; // '500MB', '1GB', '2GB', '5GB', '10GB', '20GB', 'Unlimited'
  final String downloadLocation; // 'Automatic', 'Internal Storage', 'SD Card'
  final int maxConcurrentDownloads;

  DownloadSettings copyWith({
    bool? wifiOnly,
    bool? chargingRequired,
    bool? deviceIdleRequired,
    int? minBatteryThresholdPercent,
    String? downloadQuality,
    bool? smartDownloadsEnabled,
    String? maxStorageLimit,
    String? downloadLocation,
    int? maxConcurrentDownloads,
  }) {
    return DownloadSettings(
      wifiOnly: wifiOnly ?? this.wifiOnly,
      chargingRequired: chargingRequired ?? this.chargingRequired,
      deviceIdleRequired: deviceIdleRequired ?? this.deviceIdleRequired,
      minBatteryThresholdPercent:
          minBatteryThresholdPercent ?? this.minBatteryThresholdPercent,
      downloadQuality: downloadQuality ?? this.downloadQuality,
      smartDownloadsEnabled:
          smartDownloadsEnabled ?? this.smartDownloadsEnabled,
      maxStorageLimit: maxStorageLimit ?? this.maxStorageLimit,
      downloadLocation: downloadLocation ?? this.downloadLocation,
      maxConcurrentDownloads:
          maxConcurrentDownloads ?? this.maxConcurrentDownloads,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'wifiOnly': wifiOnly,
      'chargingRequired': chargingRequired,
      'deviceIdleRequired': deviceIdleRequired,
      'minBatteryThresholdPercent': minBatteryThresholdPercent,
      'downloadQuality': downloadQuality,
      'smartDownloadsEnabled': smartDownloadsEnabled,
      'maxStorageLimit': maxStorageLimit,
      'downloadLocation': downloadLocation,
      'maxConcurrentDownloads': maxConcurrentDownloads,
    };
  }
}
