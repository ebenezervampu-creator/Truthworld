import 'package:cloud_firestore/cloud_firestore.dart';

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

  SearchResult({
    required this.id,
    required this.title,
    required this.thumbnail,
    required this.views,
    required this.channelName,
    required this.channelImage,
    required this.createdAt,
    this.type = ResultType.video,
  });

  // Getters for compatibility with EnhancedSearchController
  int get viewCount => views;
  DateTime get uploadedAt => createdAt.toDate();
  int? get duration => null; // SearchResult is lightweight, duration might not be present
  String? get quality => null; // SearchResult is lightweight, quality might not be present
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
          title: data['channelName'] as String? ?? 'Unnamed Channel',
          thumbnail: data['avatarUrl'] as String? ?? '',
          views: (data['subscriberCount'] as num?)?.toInt() ?? 0,
          channelName:
              data['handle'] as String? ?? '', // Using handle if available
          channelImage: data['avatarUrl'] as String? ?? '',
          createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
          type: ResultType.channel,
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
        );
      case ResultType.video:
        return SearchResult(
          id: doc.id,
          title: data['title'] as String? ?? 'Untitled',
          thumbnail: data['thumbnailUrl'] as String? ?? '',
          views: (data['views'] as num?)?.toInt() ?? 0,
          channelName: data['channelName'] as String? ?? 'Unknown',
          channelImage: data['channelImage'] as String? ?? '',
          createdAt: data['uploadedAt'] as Timestamp? ?? Timestamp.now(),
          type: ResultType.video,
        );
    }
  }

  /// Convert map back to SearchResult
  factory SearchResult.fromMap(Map<String, dynamic> map) {
    return SearchResult(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      thumbnail: map['thumbnail'] as String? ?? '',
      views: (map['views'] as num?)?.toInt() ?? 0,
      channelName: map['channelName'] as String? ?? '',
      channelImage: map['channelImage'] as String? ?? '',
      createdAt: map['createdAt'] is Timestamp 
          ? map['createdAt'] as Timestamp 
          : Timestamp.now(), // Fallback if serialization lost Timestamp type
      type: ResultType.values.firstWhere(
        (e) => e.toString() == (map['type'] as String?),
        orElse: () => ResultType.video,
      ),
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
    'createdAt': createdAt,
    'type': type.toString(),
  };

  @override
  String toString() => 'SearchResult($type: $id, title: $title, views: $views)';
}





