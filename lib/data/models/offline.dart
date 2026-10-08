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
    this.isEncrypted = true,
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
  final bool isEncrypted;

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
    bool? isEncrypted,
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
      isEncrypted: isEncrypted ?? this.isEncrypted,
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
    'isEncrypted': isEncrypted,
  };

  static OfflineVideo fromJson(Map<String, dynamic> json) => OfflineVideo(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    channelName: json['channelName']?.toString() ?? '',
    channelImage: json['channelImage']?.toString() ?? '',
    views: json['views']?.toString() ?? '0',
    thumbnailUrl: json['thumbnailUrl']?.toString() ?? '',
    downloadedAt: json['downloadedAt'] != null
        ? (DateTime.tryParse(json['downloadedAt'].toString()) ?? DateTime.now())
        : DateTime.now(),
    isAudioOnly: json['isAudioOnly'] as bool? ?? false,
    quality: json['quality'] as String?,
    isEncrypted: json['isEncrypted'] as bool? ?? true,
  );
}
