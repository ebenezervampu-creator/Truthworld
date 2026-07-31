class PlaybackSettings {
  const PlaybackSettings({
    this.wifiQuality = 'Auto',
    this.cellularQuality = 'Data Saver (480p)',
    this.autoplayNext = true,
    this.seekDurationSeconds = 10,
    this.volumeNormalizationMode = 'Standard',
    this.backgroundPlaybackMode = 'Off',
    this.statsForNerdsEnabled = false,
    this.showResolution = true,
    this.showDroppedFrames = true,
    this.showBitrate = true,
    this.showBufferHealth = true,
    this.showPlaybackSpeed = true,
    this.showCodec = false,
    this.showCDN = false,
  });

  factory PlaybackSettings.fromJson(Map<String, dynamic> json) {
    return PlaybackSettings(
      wifiQuality: json['wifiQuality'] as String? ?? 'Auto',
      cellularQuality:
          json['cellularQuality'] as String? ?? 'Data Saver (480p)',
      autoplayNext: json['autoplayNext'] as bool? ?? true,
      seekDurationSeconds: json['seekDurationSeconds'] as int? ?? 10,
      volumeNormalizationMode:
          json['volumeNormalizationMode'] as String? ?? 'Standard',
      backgroundPlaybackMode:
          json['backgroundPlaybackMode'] as String? ?? 'Off',
      statsForNerdsEnabled: json['statsForNerdsEnabled'] as bool? ?? false,
      showResolution: json['showResolution'] as bool? ?? true,
      showDroppedFrames: json['showDroppedFrames'] as bool? ?? true,
      showBitrate: json['showBitrate'] as bool? ?? true,
      showBufferHealth: json['showBufferHealth'] as bool? ?? true,
      showPlaybackSpeed: json['showPlaybackSpeed'] as bool? ?? true,
      showCodec: json['showCodec'] as bool? ?? false,
      showCDN: json['showCDN'] as bool? ?? false,
    );
  }
  final String wifiQuality; // 'Auto', '1080p (HD)', '720p (HD)', '480p (SD)'
  final String cellularQuality; // 'Auto', 'Data Saver (480p)', 'Low (360p)'
  final bool autoplayNext;
  final int seekDurationSeconds;
  final String
  volumeNormalizationMode; // 'Off', 'Light', 'Standard', 'Aggressive'
  final String backgroundPlaybackMode; // 'Off', 'Always On', 'Headphones Only'

  // Stats for Nerds Granular Configuration
  final bool statsForNerdsEnabled;
  final bool showResolution;
  final bool showDroppedFrames;
  final bool showBitrate;
  final bool showBufferHealth;
  final bool showPlaybackSpeed;
  final bool showCodec;
  final bool showCDN;

  PlaybackSettings copyWith({
    String? wifiQuality,
    String? cellularQuality,
    bool? autoplayNext,
    int? seekDurationSeconds,
    String? volumeNormalizationMode,
    String? backgroundPlaybackMode,
    bool? statsForNerdsEnabled,
    bool? showResolution,
    bool? showDroppedFrames,
    bool? showBitrate,
    bool? showBufferHealth,
    bool? showPlaybackSpeed,
    bool? showCodec,
    bool? showCDN,
  }) {
    return PlaybackSettings(
      wifiQuality: wifiQuality ?? this.wifiQuality,
      cellularQuality: cellularQuality ?? this.cellularQuality,
      autoplayNext: autoplayNext ?? this.autoplayNext,
      seekDurationSeconds: seekDurationSeconds ?? this.seekDurationSeconds,
      volumeNormalizationMode:
          volumeNormalizationMode ?? this.volumeNormalizationMode,
      backgroundPlaybackMode:
          backgroundPlaybackMode ?? this.backgroundPlaybackMode,
      statsForNerdsEnabled: statsForNerdsEnabled ?? this.statsForNerdsEnabled,
      showResolution: showResolution ?? this.showResolution,
      showDroppedFrames: showDroppedFrames ?? this.showDroppedFrames,
      showBitrate: showBitrate ?? this.showBitrate,
      showBufferHealth: showBufferHealth ?? this.showBufferHealth,
      showPlaybackSpeed: showPlaybackSpeed ?? this.showPlaybackSpeed,
      showCodec: showCodec ?? this.showCodec,
      showCDN: showCDN ?? this.showCDN,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'wifiQuality': wifiQuality,
      'cellularQuality': cellularQuality,
      'autoplayNext': autoplayNext,
      'seekDurationSeconds': seekDurationSeconds,
      'volumeNormalizationMode': volumeNormalizationMode,
      'backgroundPlaybackMode': backgroundPlaybackMode,
      'statsForNerdsEnabled': statsForNerdsEnabled,
      'showResolution': showResolution,
      'showDroppedFrames': showDroppedFrames,
      'showBitrate': showBitrate,
      'showBufferHealth': showBufferHealth,
      'showPlaybackSpeed': showPlaybackSpeed,
      'showCodec': showCodec,
      'showCDN': showCDN,
    };
  }
}
