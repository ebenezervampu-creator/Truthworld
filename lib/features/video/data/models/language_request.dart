import 'package:cloud_firestore/cloud_firestore.dart';

class LanguageRequest {
  final String id;
  final String videoId;
  final String channelId;
  final String userId;
  final String language;
  final String type; // 'subtitle' or 'audio'
  final Timestamp createdAt;

  LanguageRequest({
    required this.id,
    required this.videoId,
    required this.channelId,
    required this.userId,
    required this.language,
    required this.type,
    required this.createdAt,
  });

  factory LanguageRequest.fromMap(Map<String, dynamic> data, String id) {
    return LanguageRequest(
      id: id,
      videoId: data['videoId'] ?? '',
      channelId: data['channelId'] ?? '',
      userId: data['userId'] ?? '',
      language: data['language'] ?? '',
      type: data['type'] ?? 'subtitle',
      createdAt: data['createdAt'] is Timestamp 
          ? data['createdAt'] 
          : Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'videoId': videoId,
      'channelId': channelId,
      'userId': userId,
      'language': language,
      'type': type,
      'createdAt': createdAt,
    };
  }
}
