import 'package:cloud_firestore/cloud_firestore.dart';

class WatchSession {
  final String sessionId;
  final String userId;
  final String videoId;
  final int watchTimeSeconds;
  final int videoDurationSeconds;
  final double watchPercentage;
  final Timestamp timestamp;

  final bool isSubscriber;
  final bool isNotSubscriber;

  WatchSession({
    required this.sessionId,
    required this.userId,
    required this.videoId,
    required this.watchTimeSeconds,
    required this.videoDurationSeconds,
    required this.watchPercentage,
    required this.timestamp,
    this.isSubscriber = false,
    this.isNotSubscriber = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'userId': userId,
      'videoId': videoId,
      'watchTimeSeconds': watchTimeSeconds,
      'videoDurationSeconds': videoDurationSeconds,
      'watchPercentage': watchPercentage,
      'timestamp': timestamp,
      'isSubscriber': isSubscriber,
      'isNotSubscriber': isNotSubscriber,
    };
  }

  factory WatchSession.fromMap(Map<String, dynamic> map) {
    return WatchSession(
      sessionId: map['sessionId'] ?? '',
      userId: map['userId'] ?? '',
      videoId: map['videoId'] ?? '',
      watchTimeSeconds: (map['watchTimeSeconds'] as num?)?.toInt() ?? 0,
      videoDurationSeconds: (map['videoDurationSeconds'] as num?)?.toInt() ?? 0,
      watchPercentage: (map['watchPercentage'] as num?)?.toDouble() ?? 0.0,
      timestamp: map['timestamp'] ?? Timestamp.now(),
      isSubscriber: (map['isSubscriber'] as bool?) ?? false,
      isNotSubscriber: (map['isNotSubscriber'] as bool?) ?? false,
    );
  }
}





