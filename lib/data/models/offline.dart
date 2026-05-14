import 'dart:typed_data';

class OfflineVideo {
  final String id;
  final String title;
  final String channelName;
  final String channelImage;
  final String views;
  final String thumbnailUrl;
  final DateTime downloadedAt;
  final Uint8List? videoBytes; // optional: only when playing offline

  OfflineVideo({
    required this.id,
    required this.title,
    required this.channelName,
    required this.channelImage,
    required this.views,
    required this.thumbnailUrl,
    required this.downloadedAt,
    this.videoBytes,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'channelName': channelName,
    'channelImage': channelImage,
    'views': views,
    'thumbnailUrl': thumbnailUrl,
    'downloadedAt': downloadedAt.toIso8601String(),
  };

  static OfflineVideo fromJson(Map<String, dynamic> json) => OfflineVideo(
    id: json['id'],
    title: json['title'],
    channelName: json['channelName'],
    channelImage: json['channelImage'],
    views: json['views'],
    thumbnailUrl: json['thumbnailUrl'],
    downloadedAt: json['downloadedAt'] != null 
        ? DateTime.parse(json['downloadedAt']) 
        : DateTime.now(),
  );
}




