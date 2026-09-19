import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/features/analytics/data/models/watch_event/fraud_signals_model.dart';

/// Represents a single watch milestone event for a video.
/// Events are: video_start, qualified_view (20s), milestone_25, milestone_50,
/// milestone_75, milestone_100, video_exit
class WatchEvent {
  WatchEvent({
    required this.videoId,
    required this.channelId,
    required this.userId,
    required this.watchedAt,
    required this.watchedDuration,
    required this.videoDuration,
    required this.watchPercentage,
    required this.deviceType,
    required this.videoQuality,
    this.sessionId,
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
  final String
  eventType; // video_start, qualified_view, milestone_25/50/75/100, video_exit
  final String trafficSource; // Hierarchical: see TrafficSourceCategory
  final bool isSubscriber;
  final bool isReturningViewer; // See ReturningViewerDefinition
  final FraudSignals? fraudSignals; // Server-side fraud detection markers
  final String?
  serverDedupKey; // Server dedup: `{videoId}_{userHash}_{YYYYMMDD}`
  final double?
  textScaleFactor; // Captured from MediaQuery.textScalerOf(context)
  final double? devicePixelRatio;

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
  }) => WatchEvent(
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
