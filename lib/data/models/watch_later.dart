import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/utils/timestamp_utils.dart';

class WatchLater {
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

  factory WatchLater.fromDocumentSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WatchLater(
      id: doc.id,
      userId: data['userId'] ?? '',
      videoId: data['videoId'] ?? '',
      videoTitle: data['videoTitle'] ?? '',
      videoThumbnailUrl: data['videoThumbnailUrl'] ?? '',
      channelId: data['channelId'] ?? '',
      channelName: data['channelName'] ?? '',
      addedAt: TimestampUtils.parse(data['addedAt']),
      duration: data['duration'] ?? '',
      channelImage: data['channelImage'] ?? '',
      views: data['views'] ?? 0,
      uploadedAt: TimestampUtils.parse(data['uploadedAt']),
    );
  }
}





