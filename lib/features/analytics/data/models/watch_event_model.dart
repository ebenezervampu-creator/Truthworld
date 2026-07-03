import 'package:cloud_firestore/cloud_firestore.dart';

// =============================================================================
// TRAFFIC SOURCE TAXONOMY — Hierarchical categorization
// =============================================================================

/// Hierarchical traffic source taxonomy for growth analytics.
/// Level 1: Internal vs External
/// Level 2: Specific source within each category
enum TrafficSourceCategory {
  // Internal sources (within platform)
  homeFeed('home_feed', 'Home Feed', TrafficSourceType.internal),
  suggested('suggested', 'Suggested', TrafficSourceType.internal),
  search('search', 'Search', TrafficSourceType.internal),
  channelPage('channel_page', 'Channel Page', TrafficSourceType.internal),
  library('library', 'Library', TrafficSourceType.internal),
  shortsFeed('shorts_feed', 'Shorts Feed', TrafficSourceType.internal),
  trending('trending', 'Trending', TrafficSourceType.internal),
  notifications('notifications', 'Notifications', TrafficSourceType.internal),
  playlist('playlist', 'Playlist', TrafficSourceType.internal),
  endScreen('end_screen', 'End Screen', TrafficSourceType.internal),

  // External sources (outside platform)
  whatsapp('whatsapp', 'WhatsApp', TrafficSourceType.external),
  instagram('instagram', 'Instagram', TrafficSourceType.external),
  twitter('twitter', 'X / Twitter', TrafficSourceType.external),
  facebook('facebook', 'Facebook', TrafficSourceType.external),
  telegram('telegram', 'Telegram', TrafficSourceType.external),
  directLink('direct_link', 'Direct Link', TrafficSourceType.external),
  embed('embed', 'Embed', TrafficSourceType.external),
  otherExternal('other_external', 'Other External', TrafficSourceType.external),

  // Legacy / fallback
  direct('direct', 'Direct', TrafficSourceType.internal),
  unknown('unknown', 'Unknown', TrafficSourceType.internal);

  final String key;
  final String label;
  final TrafficSourceType type;

  const TrafficSourceCategory(this.key, this.label, this.type);

  /// Parse from string key
  static TrafficSourceCategory fromKey(String key) {
    return TrafficSourceCategory.values.firstWhere(
      (e) => e.key == key,
      orElse: () => TrafficSourceCategory.unknown,
    );
  }

  /// Is this an internal source?
  bool get isInternal => type == TrafficSourceType.internal;

  /// Is this an external source?
  bool get isExternal => type == TrafficSourceType.external;
}

enum TrafficSourceType { internal, external }

// =============================================================================
// FRAUD SIGNALS — Behavioral anomaly markers for watch events
// =============================================================================

/// Fraud / bot detection signals attached to each watch event.
/// Cloud Function evaluates these server-side and flags suspicious events.
class FraudSignals {
  final int viewsFromSameIP24h;       // Total views from this IP in 24h
  final int bounceLoopCount;          // Rapid start→exit cycles from same user
  final double sessionVelocity;       // Events per minute (> 10 = suspicious)
  final bool impossibleGeoJump;       // City changed faster than physically possible
  final bool suspiciousCompletion;    // 100% completion in < 30% of duration
  final bool fingerprintMismatch;     // Device fingerprint doesn't match prior session
  final double fraudScore;            // 0.0-1.0, calculated server-side
  final bool isFlagged;               // Is this event excluded from clean metrics?

  const FraudSignals({
    this.viewsFromSameIP24h = 0,
    this.bounceLoopCount = 0,
    this.sessionVelocity = 0,
    this.impossibleGeoJump = false,
    this.suspiciousCompletion = false,
    this.fingerprintMismatch = false,
    this.fraudScore = 0,
    this.isFlagged = false,
  });

  /// Is this event suspicious? (fraud score > 0.5 or explicit flag)
  bool get isSuspicious => fraudScore > 0.5 || isFlagged;

  Map<String, dynamic> toMap() => {
    'viewsFromSameIP24h': viewsFromSameIP24h,
    'bounceLoopCount': bounceLoopCount,
    'sessionVelocity': sessionVelocity,
    'impossibleGeoJump': impossibleGeoJump,
    'suspiciousCompletion': suspiciousCompletion,
    'fingerprintMismatch': fingerprintMismatch,
    'fraudScore': fraudScore,
    'isFlagged': isFlagged,
  };

  factory FraudSignals.fromMap(Map<String, dynamic> map) => FraudSignals(
    viewsFromSameIP24h: (map['viewsFromSameIP24h'] as num?)?.toInt() ?? 0,
    bounceLoopCount: (map['bounceLoopCount'] as num?)?.toInt() ?? 0,
    sessionVelocity: (map['sessionVelocity'] as num?)?.toDouble() ?? 0,
    impossibleGeoJump: map['impossibleGeoJump'] as bool? ?? false,
    suspiciousCompletion: map['suspiciousCompletion'] as bool? ?? false,
    fingerprintMismatch: map['fingerprintMismatch'] as bool? ?? false,
    fraudScore: (map['fraudScore'] as num?)?.toDouble() ?? 0,
    isFlagged: map['isFlagged'] as bool? ?? false,
  );

  static const clean = FraudSignals();
}

// =============================================================================
// RETURNING VIEWER — Strict behavioral definition
// =============================================================================

/// A returning viewer is defined as:
/// "A unique user who watched at least 1 other video on the SAME CHANNEL
///  within the past 28 days, with each session having >= 20s qualified watch."
///
/// This is evaluated SERVER-SIDE by checking:
///   watch_events_raw WHERE channelId == X AND userId == Y
///   AND eventType == 'qualified_view' AND watchedAt > now - 28d
///   AND videoId != currentVideoId
///   LIMIT 1
///
/// If a match exists → isReturningViewer = true
class ReturningViewerDefinition {
  static const int lookbackDays = 28;
  static const int minQualifiedSeconds = 20;
  static const String requiredEventType = 'qualified_view';

  /// Description for dashboard tooltip
  static const String tooltip =
      'Viewers who watched another video on this channel '
      'in the last 28 days (with 20s+ watch time each).';
}

// =============================================================================
// WATCH EVENT — Raw append-only event (written by Cloud Function)
// =============================================================================

/// Represents a single watch milestone event for a video.
/// Events are: video_start, qualified_view (20s), milestone_25, milestone_50,
/// milestone_75, milestone_100, video_exit
class WatchEvent {
  final String videoId;
  final String channelId;
  final String userId;
  final String? sessionId;
  final DateTime watchedAt;
  final int watchedDuration; // Seconds watched in this session
  final int videoDuration; // Total video duration
  final double watchPercentage; // 0-100
  final String deviceType; // mobile, desktop, tablet
  final String videoQuality; // 360p, 720p, 1080p, 4k
  final String? ipAddress; // Captured server-side only
  final String? state; // Resolved server-side from IP
  final String? city; // Resolved server-side from IP
  final String? areaType; // 'urban' or 'rural' — resolved server-side
  final String? country; // Country code
  final bool completed; // Did user watch till end?
  final bool? likedVideo;
  final int? avgBitrate;
  final String eventType; // video_start, qualified_view, milestone_25/50/75/100, video_exit
  final String trafficSource; // Hierarchical: see TrafficSourceCategory
  final bool isSubscriber;
  final bool isReturningViewer; // See ReturningViewerDefinition
  final FraudSignals? fraudSignals; // Server-side fraud detection markers
  final String? serverDedupKey; // Server dedup: `{videoId}_{userHash}_{YYYYMMDD}`
  final double? textScaleFactor; // Captured from MediaQuery.textScalerOf(context)
  final double? devicePixelRatio; // Captured from MediaQuery.devicePixelRatioOf(context)

  WatchEvent({
    required this.videoId,
    required this.channelId,
    required this.userId,
    this.sessionId,
    required this.watchedAt,
    required this.watchedDuration,
    required this.videoDuration,
    required this.watchPercentage,
    required this.deviceType,
    required this.videoQuality,
    this.ipAddress,
    this.state,
    this.city,
    this.areaType,
    this.country = 'IN',
    this.completed = false,
    this.likedVideo,
    this.avgBitrate,
    this.eventType = 'video_start',
    this.trafficSource = 'direct',
    this.isSubscriber = false,
    this.isReturningViewer = false,
    this.fraudSignals,
    this.serverDedupKey,
    this.textScaleFactor,
    this.devicePixelRatio,
  });

  /// Calculate watchtime category
  WatchtimeCategory getCategory() {
    if (watchedDuration < 20) return WatchtimeCategory.lessThan20;
    if (watchPercentage < 25) return WatchtimeCategory.lessThan25;
    if (watchPercentage < 50) return WatchtimeCategory.lessThan50;
    if (watchPercentage < 75) return WatchtimeCategory.lessThan75;
    return WatchtimeCategory.complete;
  }

  Map<String, dynamic> toMap() => {
        'videoId': videoId,
        'channelId': channelId,
        'userId': userId,
        'sessionId': sessionId,
        'watchedAt': Timestamp.fromDate(watchedAt),
        'watchedDuration': watchedDuration,
        'videoDuration': videoDuration,
        'watchPercentage': watchPercentage,
        'deviceType': deviceType,
        'videoQuality': videoQuality,
        'ipAddress': ipAddress,
        'state': state,
        'city': city,
        'areaType': areaType,
        'country': country,
        'completed': completed,
        'likedVideo': likedVideo,
        'avgBitrate': avgBitrate,
        'eventType': eventType,
        'trafficSource': trafficSource,
        'isSubscriber': isSubscriber,
        'isReturningViewer': isReturningViewer,
        'fraudSignals': fraudSignals?.toMap(),
        'serverDedupKey': serverDedupKey,
        'textScaleFactor': textScaleFactor,
        'devicePixelRatio': devicePixelRatio,
      };

  factory WatchEvent.fromMap(Map<String, dynamic> map) => WatchEvent(
        videoId: map['videoId'] as String? ?? '',
        channelId: map['channelId'] as String? ?? '',
        userId: map['userId'] as String? ?? '',
        sessionId: map['sessionId'] as String?,
        watchedAt: map['watchedAt'] is Timestamp
            ? (map['watchedAt'] as Timestamp).toDate()
            : DateTime.now(),
        watchedDuration: (map['watchedDuration'] as num?)?.toInt() ?? 0,
        videoDuration: (map['videoDuration'] as num?)?.toInt() ?? 0,
        watchPercentage: (map['watchPercentage'] as num?)?.toDouble() ?? 0,
        deviceType: map['deviceType'] as String? ?? 'mobile',
        videoQuality: map['videoQuality'] as String? ?? '720p',
        ipAddress: map['ipAddress'] as String?,
        state: map['state'] as String?,
        city: map['city'] as String?,
        areaType: map['areaType'] as String?,
        country: map['country'] as String? ?? 'IN',
        completed: map['completed'] as bool? ?? false,
        likedVideo: map['likedVideo'] as bool?,
        avgBitrate: (map['avgBitrate'] as num?)?.toInt(),
        eventType: map['eventType'] as String? ?? 'video_start',
        trafficSource: map['trafficSource'] as String? ?? 'direct',
        isSubscriber: map['isSubscriber'] as bool? ?? false,
        isReturningViewer: map['isReturningViewer'] as bool? ?? false,
        fraudSignals: map['fraudSignals'] != null
            ? FraudSignals.fromMap(map['fraudSignals'] as Map<String, dynamic>)
            : null,
        serverDedupKey: map['serverDedupKey'] as String?,
        textScaleFactor: (map['textScaleFactor'] as num?)?.toDouble(),
        devicePixelRatio: (map['devicePixelRatio'] as num?)?.toDouble(),
      );

  WatchEvent copyWith({
    String? videoId,
    String? channelId,
    String? userId,
    String? sessionId,
    DateTime? watchedAt,
    int? watchedDuration,
    int? videoDuration,
    double? watchPercentage,
    String? deviceType,
    String? videoQuality,
    String? ipAddress,
    String? state,
    String? city,
    String? areaType,
    String? country,
    bool? completed,
    bool? likedVideo,
    int? avgBitrate,
    String? eventType,
    String? trafficSource,
    bool? isSubscriber,
    bool? isReturningViewer,
    FraudSignals? fraudSignals,
    String? serverDedupKey,
    double? textScaleFactor,
    double? devicePixelRatio,
  }) =>
      WatchEvent(
        videoId: videoId ?? this.videoId,
        channelId: channelId ?? this.channelId,
        userId: userId ?? this.userId,
        sessionId: sessionId ?? this.sessionId,
        watchedAt: watchedAt ?? this.watchedAt,
        watchedDuration: watchedDuration ?? this.watchedDuration,
        videoDuration: videoDuration ?? this.videoDuration,
        watchPercentage: watchPercentage ?? this.watchPercentage,
        deviceType: deviceType ?? this.deviceType,
        videoQuality: videoQuality ?? this.videoQuality,
        ipAddress: ipAddress ?? this.ipAddress,
        state: state ?? this.state,
        city: city ?? this.city,
        areaType: areaType ?? this.areaType,
        country: country ?? this.country,
        completed: completed ?? this.completed,
        likedVideo: likedVideo ?? this.likedVideo,
        avgBitrate: avgBitrate ?? this.avgBitrate,
        eventType: eventType ?? this.eventType,
        trafficSource: trafficSource ?? this.trafficSource,
        isSubscriber: isSubscriber ?? this.isSubscriber,
        isReturningViewer: isReturningViewer ?? this.isReturningViewer,
        fraudSignals: fraudSignals ?? this.fraudSignals,
        serverDedupKey: serverDedupKey ?? this.serverDedupKey,
        textScaleFactor: textScaleFactor ?? this.textScaleFactor,
        devicePixelRatio: devicePixelRatio ?? this.devicePixelRatio,
      );
}

/// Watchtime completion categories for pie chart
enum WatchtimeCategory {
  lessThan20('< 20 sec', 'Bounced (under 20s)'),
  lessThan25('< 25%', 'Watched under 25%'),
  lessThan50('< 50%', 'Watched under 50%'),
  lessThan75('< 75%', 'Watched under 75%'),
  complete('100%', 'Watched completely');

  final String label;
  final String description;

  const WatchtimeCategory(this.label, this.description);
}

// =============================================================================
// DAILY VIDEO STATS — Pre-aggregated counter (written by Cloud Function)
// =============================================================================

/// Daily aggregated stats for a single video.
/// Document ID format: `{videoId}_{YYYY_MM_DD}`
/// Collection: `video_stats_daily`
class DailyVideoStats {
  final String videoId;
  final String channelId;
  final String dateKey; // YYYY_MM_DD
  final int totalViews; // Qualified views (20s+)
  final int totalImpressions; // Thumbnail shown count
  final int uniqueViewers;
  final int totalWatchTimeSeconds;
  final int subscriberViews;
  final int nonSubscriberViews;
  final int returningViewers;
  final int newViewers;

  // Completion buckets
  final int bouncedUnder20s;
  final int watched25Percent;
  final int watched50Percent;
  final int watched75Percent;
  final int watched100Percent;

  // Geographic
  final Map<String, int> stateTraffic; // State -> count
  final Map<String, int> cityTraffic; // City -> count
  final Map<String, int> countryTraffic; // Country -> count
  final int urbanViewers;
  final int ruralViewers;

  // Device & Quality
  final Map<String, int> deviceBreakdown;
  final Map<String, int> qualityBreakdown;

  // Traffic sources
  final Map<String, int> trafficSourceBreakdown;

  // Subscriber conversion
  final int subscribersGained;
  final int subscribersLost;

  final DateTime date;

  DailyVideoStats({
    required this.videoId,
    required this.channelId,
    required this.dateKey,
    required this.totalViews,
    this.totalImpressions = 0,
    required this.uniqueViewers,
    required this.totalWatchTimeSeconds,
    this.subscriberViews = 0,
    this.nonSubscriberViews = 0,
    this.returningViewers = 0,
    this.newViewers = 0,
    this.bouncedUnder20s = 0,
    this.watched25Percent = 0,
    this.watched50Percent = 0,
    this.watched75Percent = 0,
    this.watched100Percent = 0,
    this.stateTraffic = const {},
    this.cityTraffic = const {},
    this.countryTraffic = const {},
    this.urbanViewers = 0,
    this.ruralViewers = 0,
    this.deviceBreakdown = const {},
    this.qualityBreakdown = const {},
    this.trafficSourceBreakdown = const {},
    this.subscribersGained = 0,
    this.subscribersLost = 0,
    required this.date,
  });

  /// CTR = (views / impressions) * 100
  double get ctr =>
      totalImpressions > 0 ? (totalViews / totalImpressions) * 100 : 0;

  /// Average watch duration in seconds
  double get avgWatchDuration =>
      uniqueViewers > 0 ? totalWatchTimeSeconds / uniqueViewers : 0;

  /// Completion rate = (watched100% / uniqueViewers) * 100
  double get completionRate =>
      uniqueViewers > 0 ? (watched100Percent / uniqueViewers) * 100 : 0;

  Map<String, dynamic> toMap() => {
        'videoId': videoId,
        'channelId': channelId,
        'dateKey': dateKey,
        'totalViews': totalViews,
        'totalImpressions': totalImpressions,
        'uniqueViewers': uniqueViewers,
        'totalWatchTimeSeconds': totalWatchTimeSeconds,
        'subscriberViews': subscriberViews,
        'nonSubscriberViews': nonSubscriberViews,
        'returningViewers': returningViewers,
        'newViewers': newViewers,
        'bouncedUnder20s': bouncedUnder20s,
        'watched25Percent': watched25Percent,
        'watched50Percent': watched50Percent,
        'watched75Percent': watched75Percent,
        'watched100Percent': watched100Percent,
        'stateTraffic': stateTraffic,
        'cityTraffic': cityTraffic,
        'countryTraffic': countryTraffic,
        'urbanViewers': urbanViewers,
        'ruralViewers': ruralViewers,
        'deviceBreakdown': deviceBreakdown,
        'qualityBreakdown': qualityBreakdown,
        'trafficSourceBreakdown': trafficSourceBreakdown,
        'subscribersGained': subscribersGained,
        'subscribersLost': subscribersLost,
        'date': Timestamp.fromDate(date),
      };

  factory DailyVideoStats.fromMap(Map<String, dynamic> map) =>
      DailyVideoStats(
        videoId: map['videoId'] as String? ?? '',
        channelId: map['channelId'] as String? ?? '',
        dateKey: map['dateKey'] as String? ?? '',
        totalViews: (map['totalViews'] as num?)?.toInt() ?? 0,
        totalImpressions: (map['totalImpressions'] as num?)?.toInt() ?? 0,
        uniqueViewers: (map['uniqueViewers'] as num?)?.toInt() ?? 0,
        totalWatchTimeSeconds:
            (map['totalWatchTimeSeconds'] as num?)?.toInt() ?? 0,
        subscriberViews: (map['subscriberViews'] as num?)?.toInt() ?? 0,
        nonSubscriberViews: (map['nonSubscriberViews'] as num?)?.toInt() ?? 0,
        returningViewers: (map['returningViewers'] as num?)?.toInt() ?? 0,
        newViewers: (map['newViewers'] as num?)?.toInt() ?? 0,
        bouncedUnder20s: (map['bouncedUnder20s'] as num?)?.toInt() ?? 0,
        watched25Percent: (map['watched25Percent'] as num?)?.toInt() ?? 0,
        watched50Percent: (map['watched50Percent'] as num?)?.toInt() ?? 0,
        watched75Percent: (map['watched75Percent'] as num?)?.toInt() ?? 0,
        watched100Percent: (map['watched100Percent'] as num?)?.toInt() ?? 0,
        stateTraffic: _castIntMap(map['stateTraffic']),
        cityTraffic: _castIntMap(map['cityTraffic']),
        countryTraffic: _castIntMap(map['countryTraffic']),
        urbanViewers: (map['urbanViewers'] as num?)?.toInt() ?? 0,
        ruralViewers: (map['ruralViewers'] as num?)?.toInt() ?? 0,
        deviceBreakdown: _castIntMap(map['deviceBreakdown']),
        qualityBreakdown: _castIntMap(map['qualityBreakdown']),
        trafficSourceBreakdown: _castIntMap(map['trafficSourceBreakdown']),
        subscribersGained: (map['subscribersGained'] as num?)?.toInt() ?? 0,
        subscribersLost: (map['subscribersLost'] as num?)?.toInt() ?? 0,
        date: map['date'] is Timestamp
            ? (map['date'] as Timestamp).toDate()
            : DateTime.now(),
      );

  /// Merge two daily stats (for aggregation across date ranges)
  DailyVideoStats merge(DailyVideoStats other) {
    return DailyVideoStats(
      videoId: videoId,
      channelId: channelId,
      dateKey: dateKey,
      totalViews: totalViews + other.totalViews,
      totalImpressions: totalImpressions + other.totalImpressions,
      uniqueViewers: uniqueViewers + other.uniqueViewers,
      totalWatchTimeSeconds:
          totalWatchTimeSeconds + other.totalWatchTimeSeconds,
      subscriberViews: subscriberViews + other.subscriberViews,
      nonSubscriberViews: nonSubscriberViews + other.nonSubscriberViews,
      returningViewers: returningViewers + other.returningViewers,
      newViewers: newViewers + other.newViewers,
      bouncedUnder20s: bouncedUnder20s + other.bouncedUnder20s,
      watched25Percent: watched25Percent + other.watched25Percent,
      watched50Percent: watched50Percent + other.watched50Percent,
      watched75Percent: watched75Percent + other.watched75Percent,
      watched100Percent: watched100Percent + other.watched100Percent,
      stateTraffic: _mergeMaps(stateTraffic, other.stateTraffic),
      cityTraffic: _mergeMaps(cityTraffic, other.cityTraffic),
      countryTraffic: _mergeMaps(countryTraffic, other.countryTraffic),
      urbanViewers: urbanViewers + other.urbanViewers,
      ruralViewers: ruralViewers + other.ruralViewers,
      deviceBreakdown: _mergeMaps(deviceBreakdown, other.deviceBreakdown),
      qualityBreakdown: _mergeMaps(qualityBreakdown, other.qualityBreakdown),
      trafficSourceBreakdown:
          _mergeMaps(trafficSourceBreakdown, other.trafficSourceBreakdown),
      subscribersGained: subscribersGained + other.subscribersGained,
      subscribersLost: subscribersLost + other.subscribersLost,
      date: date,
    );
  }
}

// =============================================================================
// HOURLY VIDEO STATS — Near-realtime aggregates for fresh uploads
// =============================================================================

/// Hourly aggregated stats for a single video.
/// Document ID format: `{videoId}_{YYYY_MM_DD_HH}`
/// Collection: `video_stats_hourly`
///
/// Purpose: For videos uploaded today, creators can see real-time trends
/// without waiting for daily rollup. Hourly docs are auto-TTL'd after 72h
/// by a Cloud Function cleanup job.
class HourlyVideoStats {
  final String videoId;
  final String channelId;
  final String hourKey; // YYYY_MM_DD_HH (24h format)
  final int totalViews;
  final int uniqueViewers;
  final int totalWatchTimeSeconds;
  final int subscriberViews;
  final int nonSubscriberViews;
  final int bouncedUnder20s;
  final int watched25Percent;
  final int watched50Percent;
  final int watched75Percent;
  final int watched100Percent;
  final Map<String, int> trafficSourceBreakdown;
  final int flaggedFraudViews; // Views with fraudScore > 0.5
  final DateTime hour;

  HourlyVideoStats({
    required this.videoId,
    required this.channelId,
    required this.hourKey,
    required this.totalViews,
    required this.uniqueViewers,
    required this.totalWatchTimeSeconds,
    this.subscriberViews = 0,
    this.nonSubscriberViews = 0,
    this.bouncedUnder20s = 0,
    this.watched25Percent = 0,
    this.watched50Percent = 0,
    this.watched75Percent = 0,
    this.watched100Percent = 0,
    this.trafficSourceBreakdown = const {},
    this.flaggedFraudViews = 0,
    required this.hour,
  });

  double get avgWatchDuration =>
      uniqueViewers > 0 ? totalWatchTimeSeconds / uniqueViewers : 0;

  double get completionRate =>
      uniqueViewers > 0 ? (watched100Percent / uniqueViewers) * 100 : 0;

  /// Clean views = total - flagged fraud
  int get cleanViews => (totalViews - flaggedFraudViews).clamp(0, totalViews);

  Map<String, dynamic> toMap() => {
    'videoId': videoId,
    'channelId': channelId,
    'hourKey': hourKey,
    'totalViews': totalViews,
    'uniqueViewers': uniqueViewers,
    'totalWatchTimeSeconds': totalWatchTimeSeconds,
    'subscriberViews': subscriberViews,
    'nonSubscriberViews': nonSubscriberViews,
    'bouncedUnder20s': bouncedUnder20s,
    'watched25Percent': watched25Percent,
    'watched50Percent': watched50Percent,
    'watched75Percent': watched75Percent,
    'watched100Percent': watched100Percent,
    'trafficSourceBreakdown': trafficSourceBreakdown,
    'flaggedFraudViews': flaggedFraudViews,
    'hour': Timestamp.fromDate(hour),
  };

  factory HourlyVideoStats.fromMap(Map<String, dynamic> map) => HourlyVideoStats(
    videoId: map['videoId'] as String? ?? '',
    channelId: map['channelId'] as String? ?? '',
    hourKey: map['hourKey'] as String? ?? '',
    totalViews: (map['totalViews'] as num?)?.toInt() ?? 0,
    uniqueViewers: (map['uniqueViewers'] as num?)?.toInt() ?? 0,
    totalWatchTimeSeconds: (map['totalWatchTimeSeconds'] as num?)?.toInt() ?? 0,
    subscriberViews: (map['subscriberViews'] as num?)?.toInt() ?? 0,
    nonSubscriberViews: (map['nonSubscriberViews'] as num?)?.toInt() ?? 0,
    bouncedUnder20s: (map['bouncedUnder20s'] as num?)?.toInt() ?? 0,
    watched25Percent: (map['watched25Percent'] as num?)?.toInt() ?? 0,
    watched50Percent: (map['watched50Percent'] as num?)?.toInt() ?? 0,
    watched75Percent: (map['watched75Percent'] as num?)?.toInt() ?? 0,
    watched100Percent: (map['watched100Percent'] as num?)?.toInt() ?? 0,
    trafficSourceBreakdown: _castIntMap(map['trafficSourceBreakdown']),
    flaggedFraudViews: (map['flaggedFraudViews'] as num?)?.toInt() ?? 0,
    hour: map['hour'] is Timestamp
        ? (map['hour'] as Timestamp).toDate()
        : DateTime.now(),
  );
}

// =============================================================================
// DAILY CHANNEL STATS — Pre-aggregated per channel per day
// =============================================================================

/// Daily aggregated stats for an entire channel.
/// Document ID format: `{channelId}_{YYYY_MM_DD}`
/// Collection: `channel_stats_daily`
class DailyChannelStats {
  final String channelId;
  final String dateKey;
  final int totalViews;
  final int totalImpressions;
  final int uniqueViewers;
  final int totalWatchTimeSeconds;
  final int subscriberViews;
  final int nonSubscriberViews;
  final int returningViewers;
  final int newViewers;
  final int subscribersGained;
  final int subscribersLost;
  final int videoCount; // Videos with views this day
  final Map<String, int> stateTraffic;
  final Map<String, int> cityTraffic;
  final Map<String, int> countryTraffic;
  final int urbanViewers;
  final int ruralViewers;
  final Map<String, int> trafficSourceBreakdown;
  final DateTime date;

  DailyChannelStats({
    required this.channelId,
    required this.dateKey,
    required this.totalViews,
    this.totalImpressions = 0,
    required this.uniqueViewers,
    required this.totalWatchTimeSeconds,
    this.subscriberViews = 0,
    this.nonSubscriberViews = 0,
    this.returningViewers = 0,
    this.newViewers = 0,
    this.subscribersGained = 0,
    this.subscribersLost = 0,
    this.videoCount = 0,
    this.stateTraffic = const {},
    this.cityTraffic = const {},
    this.countryTraffic = const {},
    this.urbanViewers = 0,
    this.ruralViewers = 0,
    this.trafficSourceBreakdown = const {},
    required this.date,
  });

  double get ctr =>
      totalImpressions > 0 ? (totalViews / totalImpressions) * 100 : 0;

  double get avgWatchDuration =>
      uniqueViewers > 0 ? totalWatchTimeSeconds / uniqueViewers : 0;

  double get totalWatchHours => totalWatchTimeSeconds / 3600;

  Map<String, dynamic> toMap() => {
        'channelId': channelId,
        'dateKey': dateKey,
        'totalViews': totalViews,
        'totalImpressions': totalImpressions,
        'uniqueViewers': uniqueViewers,
        'totalWatchTimeSeconds': totalWatchTimeSeconds,
        'subscriberViews': subscriberViews,
        'nonSubscriberViews': nonSubscriberViews,
        'returningViewers': returningViewers,
        'newViewers': newViewers,
        'subscribersGained': subscribersGained,
        'subscribersLost': subscribersLost,
        'videoCount': videoCount,
        'stateTraffic': stateTraffic,
        'cityTraffic': cityTraffic,
        'countryTraffic': countryTraffic,
        'urbanViewers': urbanViewers,
        'ruralViewers': ruralViewers,
        'trafficSourceBreakdown': trafficSourceBreakdown,
        'date': Timestamp.fromDate(date),
      };

  factory DailyChannelStats.fromMap(Map<String, dynamic> map) =>
      DailyChannelStats(
        channelId: map['channelId'] as String? ?? '',
        dateKey: map['dateKey'] as String? ?? '',
        totalViews: (map['totalViews'] as num?)?.toInt() ?? 0,
        totalImpressions: (map['totalImpressions'] as num?)?.toInt() ?? 0,
        uniqueViewers: (map['uniqueViewers'] as num?)?.toInt() ?? 0,
        totalWatchTimeSeconds:
            (map['totalWatchTimeSeconds'] as num?)?.toInt() ?? 0,
        subscriberViews: (map['subscriberViews'] as num?)?.toInt() ?? 0,
        nonSubscriberViews: (map['nonSubscriberViews'] as num?)?.toInt() ?? 0,
        returningViewers: (map['returningViewers'] as num?)?.toInt() ?? 0,
        newViewers: (map['newViewers'] as num?)?.toInt() ?? 0,
        subscribersGained: (map['subscribersGained'] as num?)?.toInt() ?? 0,
        subscribersLost: (map['subscribersLost'] as num?)?.toInt() ?? 0,
        videoCount: (map['videoCount'] as num?)?.toInt() ?? 0,
        stateTraffic: _castIntMap(map['stateTraffic']),
        cityTraffic: _castIntMap(map['cityTraffic']),
        countryTraffic: _castIntMap(map['countryTraffic']),
        urbanViewers: (map['urbanViewers'] as num?)?.toInt() ?? 0,
        ruralViewers: (map['ruralViewers'] as num?)?.toInt() ?? 0,
        trafficSourceBreakdown: _castIntMap(map['trafficSourceBreakdown']),
        date: map['date'] is Timestamp
            ? (map['date'] as Timestamp).toDate()
            : DateTime.now(),
      );

  DailyChannelStats merge(DailyChannelStats other) {
    return DailyChannelStats(
      channelId: channelId,
      dateKey: dateKey,
      totalViews: totalViews + other.totalViews,
      totalImpressions: totalImpressions + other.totalImpressions,
      uniqueViewers: uniqueViewers + other.uniqueViewers,
      totalWatchTimeSeconds:
          totalWatchTimeSeconds + other.totalWatchTimeSeconds,
      subscriberViews: subscriberViews + other.subscriberViews,
      nonSubscriberViews: nonSubscriberViews + other.nonSubscriberViews,
      returningViewers: returningViewers + other.returningViewers,
      newViewers: newViewers + other.newViewers,
      subscribersGained: subscribersGained + other.subscribersGained,
      subscribersLost: subscribersLost + other.subscribersLost,
      videoCount: videoCount + other.videoCount,
      stateTraffic: _mergeMaps(stateTraffic, other.stateTraffic),
      cityTraffic: _mergeMaps(cityTraffic, other.cityTraffic),
      countryTraffic: _mergeMaps(countryTraffic, other.countryTraffic),
      urbanViewers: urbanViewers + other.urbanViewers,
      ruralViewers: ruralViewers + other.ruralViewers,
      trafficSourceBreakdown:
          _mergeMaps(trafficSourceBreakdown, other.trafficSourceBreakdown),
      date: date,
    );
  }
}

// =============================================================================
// VIDEO ANALYTICS SNAPSHOT — Computed from aggregated daily stats
// =============================================================================

/// Video-level analytics snapshot (computed from daily aggregates)
class VideoAnalyticsSnapshot {
  final String videoId;
  final String title;
  final int totalViews;
  final int totalUniqueViewers;
  final int totalImpressions;
  final double averageWatchDuration; // Seconds
  final double averageWatchPercentage; // 0-100
  final int totalWatchTimeSeconds; // Absolute total
  final int usersCompletedVideo;
  final Map<WatchtimeCategory, int> watchtimeCategoryCount;
  final Map<String, int> stateTraffic;
  final Map<String, double> stateTrafficPercentage;
  final Map<String, int> cityTraffic;
  final Map<String, double> cityTrafficPercentage;
  final Map<String, int> countryTraffic;
  final Map<String, double> countryTrafficPercentage;
  final int urbanViewers;
  final int ruralViewers;
  final Map<String, int> deviceTypeBreakdown;
  final Map<String, int> qualityBreakdown;
  final Map<String, int> trafficSourceBreakdown;
  final int subscriberViews;
  final int nonSubscriberViews;
  final int returningViewers;
  final int subscribersGained;
  final int subscribersLost;
  final int liveViewerCount; // Current concurrent viewers
  final DateTime generatedAt;
  final DateTime? nextUpdateAt;
  final int estimatedReadCount;
  final Map<DateTime, int> dailyWatchTime; // Date -> Seconds watched
  final Map<DateTime, int> dailyViews; // Date -> Views count
  final Map<DateTime, int> dailySubscribers; // Date -> Net subscribers (Gained - Lost)

  // Multi-tier fraud metric separation
  final int suspectedFraudViews; // Views flagged with fraudScore > 0.5
  final int confirmedFraudViews; // Views confirmed by manual review or rules

  VideoAnalyticsSnapshot({
    required this.videoId,
    required this.title,
    required this.totalViews,
    required this.totalUniqueViewers,
    this.totalImpressions = 0,
    required this.averageWatchDuration,
    required this.averageWatchPercentage,
    this.totalWatchTimeSeconds = 0,
    required this.usersCompletedVideo,
    required this.watchtimeCategoryCount,
    required this.stateTraffic,
    required this.stateTrafficPercentage,
    this.cityTraffic = const {},
    this.cityTrafficPercentage = const {},
    this.countryTraffic = const {},
    this.countryTrafficPercentage = const {},
    this.urbanViewers = 0,
    this.ruralViewers = 0,
    required this.deviceTypeBreakdown,
    required this.qualityBreakdown,
    this.trafficSourceBreakdown = const {},
    this.subscriberViews = 0,
    this.nonSubscriberViews = 0,
    this.returningViewers = 0,
    this.subscribersGained = 0,
    this.subscribersLost = 0,
    this.liveViewerCount = 0,
    required this.generatedAt,
    this.nextUpdateAt,
    required this.estimatedReadCount,
    this.dailyWatchTime = const {},
    this.dailyViews = const {},
    this.dailySubscribers = const {},
    this.suspectedFraudViews = 0,
    this.confirmedFraudViews = 0,
  });

  /// CTR = (views / impressions) * 100
  double get ctr =>
      totalImpressions > 0 ? (totalViews / totalImpressions) * 100 : 0;

  /// Clean views = total - suspected - confirmed fraud
  int get cleanViews =>
      (totalViews - suspectedFraudViews - confirmedFraudViews)
          .clamp(0, totalViews);

  /// Fraud rate = (suspected + confirmed) / total * 100
  double get fraudRate => totalViews > 0
      ? ((suspectedFraudViews + confirmedFraudViews) / totalViews) * 100
      : 0;

  /// View quality score (0-100): percentage of views that are clean
  double get viewQualityScore => totalViews > 0
      ? (cleanViews / totalViews) * 100
      : 100;

  /// Get top N states by traffic
  List<MapEntry<String, double>> getTopStates({int limit = 5}) {
    final sorted = stateTrafficPercentage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).toList();
  }

  /// Get top N cities by traffic
  List<MapEntry<String, double>> getTopCities({int limit = 10}) {
    final total = cityTraffic.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return [];
    final sorted = cityTraffic.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) {
      return MapEntry(e.key, (e.value / total) * 100);
    }).toList();
  }

  /// Urban percentage
  double get urbanPercentage {
    final total = urbanViewers + ruralViewers;
    return total > 0 ? (urbanViewers / total) * 100 : 0;
  }

  /// Rural percentage
  double get ruralPercentage {
    final total = urbanViewers + ruralViewers;
    return total > 0 ? (ruralViewers / total) * 100 : 0;
  }

  /// Formatted total watch time
  String get totalWatchTimeFormatted {
    if (totalWatchTimeSeconds < 60) return '${totalWatchTimeSeconds}s';
    final hours = totalWatchTimeSeconds ~/ 3600;
    final minutes = (totalWatchTimeSeconds % 3600) / 60;
    if (hours > 0) return '${hours}h ${minutes.toInt()}m';
    if (minutes < 10) return '${minutes.toStringAsFixed(1)}m';
    return '${minutes.toInt()}m';
  }

  /// Get completion rate percentage
  double getCompletionRate() => totalUniqueViewers > 0
      ? (usersCompletedVideo / totalUniqueViewers) * 100
      : 0;

  /// Get engagement score (0-100)
  double getEngagementScore() {
    final completionRate = getCompletionRate();
    final avgWatchRate = averageWatchPercentage;
    return (completionRate * 0.6) + (avgWatchRate * 0.4);
  }

  /// Subscriber conversion rate
  double get subscriberConversionRate =>
      totalViews > 0 ? (subscribersGained / totalViews) * 100 : 0;

  Map<String, dynamic> toMap() => {
        'videoId': videoId,
        'title': title,
        'totalViews': totalViews,
        'totalUniqueViewers': totalUniqueViewers,
        'totalImpressions': totalImpressions,
        'averageWatchDuration': averageWatchDuration,
        'averageWatchPercentage': averageWatchPercentage,
        'totalWatchTimeSeconds': totalWatchTimeSeconds,
        'usersCompletedVideo': usersCompletedVideo,
        'watchtimeCategoryCount':
            watchtimeCategoryCount.map((k, v) => MapEntry(k.name, v)),
        'stateTraffic': stateTraffic,
        'stateTrafficPercentage': stateTrafficPercentage,
        'cityTraffic': cityTraffic,
        'cityTrafficPercentage': cityTrafficPercentage,
        'countryTraffic': countryTraffic,
        'countryTrafficPercentage': countryTrafficPercentage,
        'urbanViewers': urbanViewers,
        'ruralViewers': ruralViewers,
        'deviceTypeBreakdown': deviceTypeBreakdown,
        'qualityBreakdown': qualityBreakdown,
        'trafficSourceBreakdown': trafficSourceBreakdown,
        'subscriberViews': subscriberViews,
        'nonSubscriberViews': nonSubscriberViews,
        'returningViewers': returningViewers,
        'subscribersGained': subscribersGained,
        'subscribersLost': subscribersLost,
        'liveViewerCount': liveViewerCount,
        'generatedAt': Timestamp.fromDate(generatedAt),
        'nextUpdateAt':
            nextUpdateAt != null ? Timestamp.fromDate(nextUpdateAt!) : null,
        'estimatedReadCount': estimatedReadCount,
        'dailyWatchTime': dailyWatchTime.map((k, v) => MapEntry(k.toIso8601String(), v)),
        'dailyViews': dailyViews.map((k, v) => MapEntry(k.toIso8601String(), v)),
        'dailySubscribers': dailySubscribers.map((k, v) => MapEntry(k.toIso8601String(), v)),
        'suspectedFraudViews': suspectedFraudViews,
        'confirmedFraudViews': confirmedFraudViews,
      };

  factory VideoAnalyticsSnapshot.fromMap(Map<String, dynamic> map) {
    final wtcCount = <WatchtimeCategory, int>{};
    (map['watchtimeCategoryCount'] as Map<String, dynamic>?)
        ?.forEach((key, value) {
      final category = WatchtimeCategory.values.firstWhere(
        (e) => e.name == key,
        orElse: () => WatchtimeCategory.lessThan20,
      );
      wtcCount[category] = (value as num).toInt();
    });

    return VideoAnalyticsSnapshot(
      videoId: map['videoId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      totalViews: (map['totalViews'] as num?)?.toInt() ?? 0,
      totalUniqueViewers: (map['totalUniqueViewers'] as num?)?.toInt() ?? 0,
      totalImpressions: (map['totalImpressions'] as num?)?.toInt() ?? 0,
      averageWatchDuration:
          (map['averageWatchDuration'] as num?)?.toDouble() ?? 0,
      averageWatchPercentage:
          (map['averageWatchPercentage'] as num?)?.toDouble() ?? 0,
      totalWatchTimeSeconds:
          (map['totalWatchTimeSeconds'] as num?)?.toInt() ?? 0,
      usersCompletedVideo:
          (map['usersCompletedVideo'] as num?)?.toInt() ?? 0,
      watchtimeCategoryCount: wtcCount,
      stateTraffic: _castIntMap(map['stateTraffic']),
      stateTrafficPercentage: _castDoubleMap(map['stateTrafficPercentage']),
      cityTraffic: _castIntMap(map['cityTraffic']),
      cityTrafficPercentage: _castDoubleMap(map['cityTrafficPercentage']),
      countryTraffic: _castIntMap(map['countryTraffic']),
      countryTrafficPercentage: _castDoubleMap(map['countryTrafficPercentage']),
      urbanViewers: (map['urbanViewers'] as num?)?.toInt() ?? 0,
      ruralViewers: (map['ruralViewers'] as num?)?.toInt() ?? 0,
      deviceTypeBreakdown: _castIntMap(map['deviceTypeBreakdown']),
      qualityBreakdown: _castIntMap(map['qualityBreakdown']),
      trafficSourceBreakdown: _castIntMap(map['trafficSourceBreakdown']),
      subscriberViews: (map['subscriberViews'] as num?)?.toInt() ?? 0,
      nonSubscriberViews: (map['nonSubscriberViews'] as num?)?.toInt() ?? 0,
      returningViewers: (map['returningViewers'] as num?)?.toInt() ?? 0,
      subscribersGained: (map['subscribersGained'] as num?)?.toInt() ?? 0,
      subscribersLost: (map['subscribersLost'] as num?)?.toInt() ?? 0,
      liveViewerCount: (map['liveViewerCount'] as num?)?.toInt() ?? 0,
      generatedAt: map['generatedAt'] is Timestamp
          ? (map['generatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      nextUpdateAt: map['nextUpdateAt'] != null && map['nextUpdateAt'] is Timestamp
          ? (map['nextUpdateAt'] as Timestamp).toDate()
          : null,
      estimatedReadCount: (map['estimatedReadCount'] as num?)?.toInt() ?? 0,
      dailyWatchTime: _castDateIntMap(map['dailyWatchTime']),
      dailyViews: _castDateIntMap(map['dailyViews']),
      dailySubscribers: _castDateIntMap(map['dailySubscribers']),
      suspectedFraudViews: (map['suspectedFraudViews'] as num?)?.toInt() ?? 0,
      confirmedFraudViews: (map['confirmedFraudViews'] as num?)?.toInt() ?? 0,
    );
  }
}

// =============================================================================
// CHANNEL ANALYTICS SNAPSHOT — Computed from daily aggregates
// =============================================================================

/// Channel-level aggregated analytics
class ChannelAnalyticsSnapshot {
  final String channelId;
  final String channelName;
  final int totalVideoWatches;
  final int totalUniqueViewers;
  final int totalImpressions;
  final double averageWatchDuration;
  final double averageWatchPercentage;
  final int totalWatchTimeSeconds; // Absolute cumulative
  final Map<String, int> stateTraffic;
  final Map<String, double> stateTrafficPercentage;
  final Map<String, int> cityTraffic;
  final Map<String, double> cityTrafficPercentage;
  final Map<String, int> countryTraffic;
  final Map<String, double> countryTrafficPercentage;
  final int urbanViewers;
  final int ruralViewers;
  final Map<String, int> trafficSourceBreakdown;
  final Map<DateTime, int> dailyWatchTime;
  final Map<DateTime, int> dailyViews;
  final Map<DateTime, int> dailySubscribers;
  final DateTime generatedAt;
  final int videoCount;
  final double totalEngagementScore;
  final int subscriberViews;
  final int nonSubscriberViews;
  final int returningViewers;
  final int subscribersGained;
  final int subscribersLost;
  final int liveViewerCount;

  ChannelAnalyticsSnapshot({
    required this.channelId,
    required this.channelName,
    required this.totalVideoWatches,
    required this.totalUniqueViewers,
    this.totalImpressions = 0,
    required this.averageWatchDuration,
    required this.averageWatchPercentage,
    this.totalWatchTimeSeconds = 0,
    required this.stateTraffic,
    required this.stateTrafficPercentage,
    this.cityTraffic = const {},
    this.cityTrafficPercentage = const {},
    this.countryTraffic = const {},
    this.countryTrafficPercentage = const {},
    this.urbanViewers = 0,
    this.ruralViewers = 0,
    this.trafficSourceBreakdown = const {},
    this.dailyWatchTime = const {},
    this.dailyViews = const {},
    this.dailySubscribers = const {},
    required this.generatedAt,
    required this.videoCount,
    required this.totalEngagementScore,
    this.subscriberViews = 0,
    this.nonSubscriberViews = 0,
    this.returningViewers = 0,
    this.subscribersGained = 0,
    this.subscribersLost = 0,
    this.liveViewerCount = 0,
  });

  /// Total watch hours across channel
  double get totalWatchHours => totalWatchTimeSeconds / 3600;

  /// Formatted total watch time
  String get totalWatchTimeFormatted {
    if (totalWatchTimeSeconds < 60) return '${totalWatchTimeSeconds}s';
    final hours = totalWatchTimeSeconds ~/ 3600;
    final minutes = (totalWatchTimeSeconds % 3600) / 60;
    if (hours > 0) return '${hours}h ${minutes.toInt()}m';
    if (minutes < 10) return '${minutes.toStringAsFixed(1)}m';
    return '${minutes.toInt()}m';
  }

  /// CTR
  double get ctr =>
      totalImpressions > 0 ? (totalVideoWatches / totalImpressions) * 100 : 0;

  /// Average engagement score per video
  double getAverageEngagementScore() =>
      videoCount > 0 ? totalEngagementScore / videoCount : 0;

  /// Urban percentage
  double get urbanPercentage {
    final total = urbanViewers + ruralViewers;
    return total > 0 ? (urbanViewers / total) * 100 : 0;
  }

  /// Rural percentage
  double get ruralPercentage {
    final total = urbanViewers + ruralViewers;
    return total > 0 ? (ruralViewers / total) * 100 : 0;
  }

  /// Subscriber conversion rate
  double get subscriberConversionRate =>
      totalVideoWatches > 0
          ? (subscribersGained / totalVideoWatches) * 100
          : 0;

  Map<String, dynamic> toMap() => {
        'channelId': channelId,
        'channelName': channelName,
        'totalVideoWatches': totalVideoWatches,
        'totalUniqueViewers': totalUniqueViewers,
        'totalImpressions': totalImpressions,
        'averageWatchDuration': averageWatchDuration,
        'averageWatchPercentage': averageWatchPercentage,
        'totalWatchTimeSeconds': totalWatchTimeSeconds,
        'stateTraffic': stateTraffic,
        'stateTrafficPercentage': stateTrafficPercentage,
        'cityTraffic': cityTraffic,
        'cityTrafficPercentage': cityTrafficPercentage,
        'countryTraffic': countryTraffic,
        'countryTrafficPercentage': countryTrafficPercentage,
        'urbanViewers': urbanViewers,
        'ruralViewers': ruralViewers,
        'trafficSourceBreakdown': trafficSourceBreakdown,
        'dailyWatchTime': dailyWatchTime.map((k, v) => MapEntry(k.toIso8601String(), v)),
        'dailyViews': dailyViews.map((k, v) => MapEntry(k.toIso8601String(), v)),
        'dailySubscribers': dailySubscribers.map((k, v) => MapEntry(k.toIso8601String(), v)),
        'generatedAt': Timestamp.fromDate(generatedAt),
        'videoCount': videoCount,
        'totalEngagementScore': totalEngagementScore,
        'subscriberViews': subscriberViews,
        'nonSubscriberViews': nonSubscriberViews,
        'returningViewers': returningViewers,
        'subscribersGained': subscribersGained,
        'subscribersLost': subscribersLost,
        'liveViewerCount': liveViewerCount,
      };

  factory ChannelAnalyticsSnapshot.fromMap(Map<String, dynamic> map) =>
      ChannelAnalyticsSnapshot(
        channelId: map['channelId'] as String? ?? '',
        channelName: map['channelName'] as String? ?? '',
        totalVideoWatches: (map['totalVideoWatches'] as num?)?.toInt() ?? 0,
        totalUniqueViewers: (map['totalUniqueViewers'] as num?)?.toInt() ?? 0,
        totalImpressions: (map['totalImpressions'] as num?)?.toInt() ?? 0,
        averageWatchDuration:
            (map['averageWatchDuration'] as num?)?.toDouble() ?? 0,
        averageWatchPercentage:
            (map['averageWatchPercentage'] as num?)?.toDouble() ?? 0,
        totalWatchTimeSeconds:
            (map['totalWatchTimeSeconds'] as num?)?.toInt() ?? 0,
        stateTraffic: _castIntMap(map['stateTraffic']),
        stateTrafficPercentage: _castDoubleMap(map['stateTrafficPercentage']),
        cityTraffic: _castIntMap(map['cityTraffic']),
        cityTrafficPercentage: _castDoubleMap(map['cityTrafficPercentage']),
        countryTraffic: _castIntMap(map['countryTraffic']),
        countryTrafficPercentage: _castDoubleMap(map['countryTrafficPercentage']),
        urbanViewers: (map['urbanViewers'] as num?)?.toInt() ?? 0,
        ruralViewers: (map['ruralViewers'] as num?)?.toInt() ?? 0,
        trafficSourceBreakdown: _castIntMap(map['trafficSourceBreakdown']),
        dailyWatchTime: _castDateIntMap(map['dailyWatchTime']),
        dailyViews: _castDateIntMap(map['dailyViews']),
        dailySubscribers: _castDateIntMap(map['dailySubscribers']),
        generatedAt: map['generatedAt'] is Timestamp
            ? (map['generatedAt'] as Timestamp).toDate()
            : DateTime.now(),
        videoCount: (map['videoCount'] as num?)?.toInt() ?? 0,
        totalEngagementScore:
            (map['totalEngagementScore'] as num?)?.toDouble() ?? 0,
        subscriberViews: (map['subscriberViews'] as num?)?.toInt() ?? 0,
        nonSubscriberViews: (map['nonSubscriberViews'] as num?)?.toInt() ?? 0,
        returningViewers: (map['returningViewers'] as num?)?.toInt() ?? 0,
        subscribersGained: (map['subscribersGained'] as num?)?.toInt() ?? 0,
        subscribersLost: (map['subscribersLost'] as num?)?.toInt() ?? 0,
        liveViewerCount: (map['liveViewerCount'] as num?)?.toInt() ?? 0,
      );
}

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

Map<String, int> _castIntMap(dynamic source) {
  if (source == null) return {};
  if (source is Map<String, dynamic>) {
    return source.map((k, v) => MapEntry(k, (v as num).toInt()));
  }
  return {};
}

Map<String, double> _castDoubleMap(dynamic source) {
  if (source == null) return {};
  if (source is Map<String, dynamic>) {
    return source.map((k, v) => MapEntry(k, (v as num).toDouble()));
  }
  return {};
}

Map<DateTime, int> _castDateIntMap(dynamic source) {
  if (source == null) return {};
  if (source is Map<String, dynamic>) {
    return source.map((k, v) => MapEntry(DateTime.parse(k), (v as num).toInt()));
  }
  return {};
}

Map<String, int> _mergeMaps(Map<String, int> a, Map<String, int> b) {
  final result = Map<String, int>.from(a);
  for (final entry in b.entries) {
    result[entry.key] = (result[entry.key] ?? 0) + entry.value;
  }
  return result;
}

class GeoRegionModel {
  final String regionKey;
  final int count;
  final bool isIndianState;

  const GeoRegionModel({
    required this.regionKey,
    required this.count,
    required this.isIndianState,
  });

  Map<String, dynamic> toMap() => {
        'regionKey': regionKey,
        'count': count,
        'isIndianState': isIndianState,
      };

  factory GeoRegionModel.fromMap(Map<String, dynamic> map) => GeoRegionModel(
        regionKey: map['regionKey'] as String? ?? '',
        count: (map['count'] as num?)?.toInt() ?? 0,
        isIndianState: map['isIndianState'] as bool? ?? false,
      );
}

class RetentionFunnelModel {
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
}






