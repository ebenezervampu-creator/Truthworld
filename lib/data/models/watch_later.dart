import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/utils/timestamp_utils.dart';

class WatchLater {
  WatchLater({
    required this.id,
    required this.userId,
    required this.videoId,
    required this.videoTitle,
    required this.videoThumbnailUrl,
    required this.channelId,
    required this.channelName,
    required this.addedAt,
    required this.duration,
    required this.channelImage,
    required this.views,
    required this.uploadedAt,
  });

  factory WatchLater.fromMap(Map<String, dynamic> data, [String? docId]) {
    return WatchLater(
      id: docId ?? (data['id'] as String? ?? ''),
      userId: data['userId'] as String? ?? '',
      videoId: data['videoId'] as String? ?? '',
      videoTitle: data['videoTitle'] as String? ?? '',
      videoThumbnailUrl: data['videoThumbnailUrl'] as String? ?? '',
      channelId: data['channelId'] as String? ?? '',
      channelName: data['channelName'] as String? ?? '',
      addedAt: TimestampUtils.parse(data['addedAt']),
      duration: data['duration'] as String? ?? '',
      channelImage: data['channelImage'] as String? ?? '',
      views: (data['views'] as num?)?.toInt() ?? 0,
      uploadedAt: TimestampUtils.parse(data['uploadedAt']),
    );
  }

  factory WatchLater.fromDocumentSnapshot(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return WatchLater.fromMap(data, doc.id);
  }
  final String id;
  final String userId;
  final String videoId;
  final String videoTitle;
  final String videoThumbnailUrl;
  final String channelId;
  final String channelName;
  final Timestamp addedAt;
  final String duration;
  final String channelImage;
  final int views;

  final Timestamp uploadedAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'videoId': videoId,
      'videoTitle': videoTitle,
      'videoThumbnailUrl': videoThumbnailUrl,
      'channelId': channelId,
      'channelName': channelName,
      'addedAt': addedAt,
      'duration': duration,
      'channelImage': channelImage,
      'views': views,
      'uploadedAt': uploadedAt,
    };
  }
}
