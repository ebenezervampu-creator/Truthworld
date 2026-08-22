import 'dart:typed_data';

class OfflineVideo {
  // optional: only when playing offline

  OfflineVideo({
    required this.id,
    required this.title,
    required this.channelName,
    required this.channelImage,
    required this.views,
    required this.thumbnailUrl,
    required this.downloadedAt,
    this.videoBytes,
    this.isAudioOnly = false,
    this.quality,
  });
  final String id;
  final String title;
  final String channelName;
  final String channelImage;
  final String views;
  final String thumbnailUrl;
  final DateTime downloadedAt;
  final Uint8List? videoBytes;
  final bool isAudioOnly;
  final String? quality;

  OfflineVideo copyWith({
    String? id,
    String? title,
    String? channelName,
    String? channelImage,
    String? views,
    String? thumbnailUrl,
    DateTime? downloadedAt,
    Uint8List? videoBytes,
    bool? isAudioOnly,
    String? quality,
  }) {
    return OfflineVideo(
      id: id ?? this.id,
      title: title ?? this.title,
      channelName: channelName ?? this.channelName,
      channelImage: channelImage ?? this.channelImage,
      views: views ?? this.views,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      videoBytes: videoBytes ?? this.videoBytes,
      isAudioOnly: isAudioOnly ?? this.isAudioOnly,
      quality: quality ?? this.quality,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'channelName': channelName,
    'channelImage': channelImage,
    'views': views,
    'thumbnailUrl': thumbnailUrl,
    'downloadedAt': downloadedAt.toIso8601String(),
    'isAudioOnly': isAudioOnly,
    if (quality != null) 'quality': quality,
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
    isAudioOnly: json['isAudioOnly'] as bool? ?? false,
    quality: json['quality'] as String?,
  );
}
