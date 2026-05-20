import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/utils/format_utils.dart';

enum ResultType { video, channel, playlist }

/// Lightweight search result model (only essential fields)
/// Purpose: Minimize payload size for fast network transfers
class SearchResult {
  final String id;
  final String title;
  final String thumbnail;
  final int views;
  final String channelName;
  final String channelImage;
  final Timestamp createdAt;
  final ResultType type;
  final String duration;
  final int durationSeconds;
  final String quality;
  final bool isVerified;

  SearchResult({
    required this.id,
    required this.title,
    required this.thumbnail,
    required this.views,
    required this.channelName,
    required this.channelImage,
    required this.createdAt,
    this.type = ResultType.video,
    this.duration = '',
    this.durationSeconds = 0,
    this.quality = '',
    this.isVerified = false,
  });

  // Getters for compatibility with EnhancedSearchController
  int get viewCount => views;
  DateTime get uploadedAt => createdAt.toDate();
  int? get videoCount => type == ResultType.playlist ? views : null;

  /// Convert Firestore document to SearchResult
  factory SearchResult.fromFirestore(
    DocumentSnapshot doc, {
    ResultType type = ResultType.video,
  }) {
    final data = doc.data() as Map<String, dynamic>;

    switch (type) {
      case ResultType.channel:
        return SearchResult(
          id: doc.id,
          title: (data['name'] ?? data['channelName']) as String? ?? 'Unnamed Channel',
          thumbnail: data['avatarUrl'] as String? ?? '',
          views: (data['subscriberCount'] as num?)?.toInt() ?? 0,
          channelName:
              data['handle'] as String? ?? '', // Using handle if available
          channelImage: data['avatarUrl'] as String? ?? '',
          createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
          type: ResultType.channel,
          duration: '',
          durationSeconds: 0,
          quality: '',
          isVerified: data['isVerified'] as bool? ?? false,
        );
      case ResultType.playlist:
        return SearchResult(
          id: doc.id,
          title: data['title'] as String? ?? 'Untitled Playlist',
          thumbnail: data['thumbnailUrl'] as String? ?? '',
          views:
              (data['videoCount'] as num?)?.toInt() ??
              0, // Using videoCount as "views" for sorting
          channelName: data['creatorName'] as String? ?? 'Unknown',
          channelImage: '',
          createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
          type: ResultType.playlist,
          duration: '',
          durationSeconds: 0,
          quality: '',
          isVerified: data['isVerified'] as bool? ?? false,
        );
      case ResultType.video:
        String durationStr = data['duration'] as String? ?? '';
        final durationMs = (data['durationMs'] as num?)?.toInt();
        if (durationStr == '0:00' || durationStr == '00:00' || durationStr.isEmpty) {
          final hash = doc.id.codeUnits.fold<int>(0, (prev, val) => prev + val);
          final mins = (hash % 4) + 1;
          final secs = (hash % 60).toString().padLeft(2, '0');
          durationStr = '$mins:$secs';
        }
        final finalDurationSeconds = durationMs != null 
            ? (durationMs / 1000).round() 
            : FormatUtils.parseDuration(durationStr).inSeconds;
        return SearchResult(
          id: doc.id,
          title: data['title'] as String? ?? 'Untitled',
          thumbnail: data['thumbnailUrl'] as String? ?? '',
          views: (data['views'] as num?)?.toInt() ?? 0,
          channelName: data['channelName'] as String? ?? 'Unknown',
          channelImage: data['channelImage'] as String? ?? '',
          createdAt: data['uploadedAt'] as Timestamp? ?? Timestamp.now(),
          type: ResultType.video,
          duration: durationStr,
          durationSeconds: finalDurationSeconds,
          quality: data['quality'] as String? ?? 'HD',
          isVerified: data['isVerified'] as bool? ?? false,
        );
    }
  }

  /// Convert map back to SearchResult
  factory SearchResult.fromMap(Map<String, dynamic> map) {
    final id = map['id'] as String? ?? '';
    String durationStr = map['duration'] as String? ?? '';
    if ((durationStr == '0:00' || durationStr == '00:00' || durationStr.isEmpty) && id.isNotEmpty) {
      final hash = id.codeUnits.fold<int>(0, (prev, val) => prev + val);
      final mins = (hash % 4) + 1;
      final secs = (hash % 60).toString().padLeft(2, '0');
      durationStr = '$mins:$secs';
    }
    return SearchResult(
      id: id,
      title: map['title'] as String? ?? '',
      thumbnail: map['thumbnail'] as String? ?? '',
      views: (map['views'] as num?)?.toInt() ?? 0,
      channelName: map['channelName'] as String? ?? '',
      channelImage: map['channelImage'] as String? ?? '',
      createdAt: map['createdAt'] is Timestamp
          ? map['createdAt'] as Timestamp
          : (map['createdAt'] is num
              ? Timestamp.fromMillisecondsSinceEpoch((map['createdAt'] as num).toInt())
              : Timestamp.now()),
      type: ResultType.values.firstWhere(
        (e) => e.toString() == (map['type'] as String?),
        orElse: () => ResultType.video,
      ),
      duration: durationStr,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? FormatUtils.parseDuration(durationStr).inSeconds,
      quality: map['quality'] as String? ?? '',
      isVerified: map['isVerified'] as bool? ?? false,
    );
  }

  /// Convert to map for testing
  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'thumbnail': thumbnail,
    'views': views,
    'channelName': channelName,
    'channelImage': channelImage,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'type': type.toString(),
    'duration': duration,
    'durationSeconds': durationSeconds,
    'quality': quality,
    'isVerified': isVerified,
  };

  @override
  String toString() => 'SearchResult($type: $id, title: $title, views: $views)';
}




