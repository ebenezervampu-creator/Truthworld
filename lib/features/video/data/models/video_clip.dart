import 'package:cloud_firestore/cloud_firestore.dart';

class VideoClip {
  final String id;
  final String videoId;
  final String userId;
  final String title;
  final double startTime; // in seconds
  final double endTime; // in seconds
  final String thumbnailUrl;
  final String videoTitle;
  final String channelName;
  final DateTime createdAt;

  VideoClip({
    required this.id,
    required this.videoId,
    required this.userId,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.thumbnailUrl,
    required this.videoTitle,
    required this.channelName,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'videoId': videoId,
      'userId': userId,
      'title': title,
      'startTime': startTime,
      'endTime': endTime,
      'thumbnailUrl': thumbnailUrl,
      'videoTitle': videoTitle,
      'channelName': channelName,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory VideoClip.fromMap(Map<String, dynamic> map) {
    return VideoClip(
      id: map['id'] ?? '',
      videoId: map['videoId'] ?? '',
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      startTime: (map['startTime'] as num?)?.toDouble() ?? 0.0,
      endTime: (map['endTime'] as num?)?.toDouble() ?? 0.0,
      thumbnailUrl: map['thumbnailUrl'] ?? '',
      videoTitle: map['videoTitle'] ?? '',
      channelName: map['channelName'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory VideoClip.fromDocumentSnapshot(DocumentSnapshot doc) {
    return VideoClip.fromMap(doc.data() as Map<String, dynamic>);
  }
}




