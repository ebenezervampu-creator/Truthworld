import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/utils/timestamp_utils.dart';

enum ResultType { video, channel, playlist, topic }

/// Lightweight search result model (only essential fields)
/// Purpose: Minimize payload size for fast network transfers
class SearchResult {
  SearchResult({
    required this.id,
    required this.title,
    required this.thumbnail,
    required this.views,
    required this.channelName,
    required this.channelImage,
    required this.createdAt,
    this.type = ResultType.video,
    this.durationMs,
    this.relevanceScore = 0.0,
  });

  /// Convert Firestore document to SearchResult
  factory SearchResult.fromFirestore(
    DocumentSnapshot doc, {
    ResultType type = ResultType.video,
  }) {
    final data = doc.data()! as Map<String, dynamic>;

    switch (type) {
      case ResultType.channel:
        final channelTitle = data['channelName'] as String? ??
            data['name'] as String? ??
            data['displayName'] as String? ??
            'Channel';
        final avatar = data['avatarUrl'] as String? ??
            data['photoUrl'] as String? ??
            data['channelImage'] as String? ??
            data['profileImageUrl'] as String? ??
            '';
        final subs = (data['subscriberCount'] as num?)?.toInt() ??
            (data['subscribers'] as num?)?.toInt() ??
            (data['subscriber_count'] as num?)?.toInt() ??
            0;
        final handle = data['handle'] as String? ??
            data['channelHandle'] as String? ??
            (data['customUrl'] as String? ?? '');

        return SearchResult(
          id: doc.id,
          title: channelTitle,
          thumbnail: avatar,
          views: subs,
          channelName: handle.isNotEmpty ? (handle.startsWith('@') ? handle : '@$handle') : channelTitle,
          channelImage: avatar,
          createdAt: TimestampUtils.parse(data['createdAt']),
          type: ResultType.channel,
        );
      case ResultType.playlist:
        final playlistTitle = data['name'] as String? ??
            data['playlistName'] as String? ??
            data['title'] as String? ??
            'Playlist';
        final playlistThumb = data['thumbnailUrl'] as String? ??
            data['thumbnail'] as String? ??
            data['coverUrl'] as String? ??
            '';
        final vidCount = (data['videoCount'] as num?)?.toInt() ??
            (data['videosCount'] as num?)?.toInt() ??
            (data['videoIds'] as List?)?.length ??
            0;
        final creator = data['creatorName'] as String? ??
            data['channelName'] as String? ??
            data['ownerName'] as String? ??
            'Truthworld';

        return SearchResult(
          id: doc.id,
          title: playlistTitle,
          thumbnail: playlistThumb,
          views: vidCount,
          channelName: creator,
          channelImage: '',
          createdAt: TimestampUtils.parse(data['createdAt']),
          type: ResultType.playlist,
        );
      case ResultType.topic:
        final slugVal = data['slug'] as String? ?? '';
        final topicTitle = data['title'] as String? ??
            data['name'] as String? ??
            data['topicName'] as String? ??
            (slugVal.isNotEmpty ? slugVal.replaceAll('-', ' ') : 'Topic');
        final topicThumb = data['thumbnailUrl'] as String? ??
            data['thumbnail'] as String? ??
            data['coverImage'] as String? ??
            data['imageUrl'] as String? ??
            '';
        final topicCount = (data['videoCount'] as num?)?.toInt() ??
            (data['followerCount'] as num?)?.toInt() ??
            (data['followersCount'] as num?)?.toInt() ??
            (data['views'] as num?)?.toInt() ??
            0;
        final handleVal = data['handle'] as String? ??
            (slugVal.isNotEmpty ? 'T/$slugVal' : 'Topic');

        return SearchResult(
          id: doc.id,
          title: topicTitle,
          thumbnail: topicThumb,
          views: topicCount,
          channelName: handleVal,
          channelImage: '',
          createdAt: TimestampUtils.parse(data['createdAt']),
          type: ResultType.topic,
        );
      case ResultType.video:
        return SearchResult(
          id: doc.id,
          title: data['title'] as String? ?? 'Untitled',
          thumbnail: data['thumbnailUrl'] as String? ?? '',
          views: (data['viewCount'] as num?)?.toInt() ??
              (data['views'] as num?)?.toInt() ??
              (data['stats'] is Map
                  ? (data['stats']['views'] as num?)?.toInt()
                  : null) ??
              0,
          channelName: data['channelName'] as String? ?? 'Unknown',
          channelImage: data['channelAvatarUrl'] as String? ??
              data['channelImage'] as String? ??
              '',
          createdAt: TimestampUtils.parse(
            data['uploadedAt'] ?? data['createdAt'],
          ),
          durationMs: (data['durationMs'] as num?)?.toInt(),
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
      createdAt: TimestampUtils.parse(
        map['createdAt'],
      ), // Fallback if serialization lost Timestamp type
      type: ResultType.values.firstWhere(
        (e) => e.toString() == (map['type'] as String?),
        orElse: () => ResultType.video,
      ),
      durationMs: (map['durationMs'] as num?)?.toInt(),
    );
  }
  final String id;
  final String title;
  final String thumbnail;
  final int views;
  final String channelName;
  final String channelImage;
  final Timestamp createdAt;
  final ResultType type;
  final int? durationMs;
  double relevanceScore;

  // Getters for compatibility with EnhancedSearchController
  int get viewCount => views;
  DateTime get uploadedAt => createdAt.toDate();
  int? get duration => durationMs != null ? (durationMs! ~/ 1000) : null;
  String? get quality =>
      null; // SearchResult is lightweight, quality might not be present
  int? get videoCount =>
      type == ResultType.playlist || type == ResultType.topic ? views : null;

  bool get isValid {
    final t = title.trim().toLowerCase();
    if (t.isEmpty) return false;
    if (type == ResultType.video) {
      if (t == 'untitled' ||
          t == 'untitled video' ||
          t == 'untitled draft' ||
          t == 'uploading...' ||
          t.startsWith('untitled draft') ||
          t.startsWith('uploading')) {
        return false;
      }
    }
    return true;
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
    'durationMs': durationMs,
  };

  @override
  String toString() => 'SearchResult($type: $id, title: $title, views: $views)';
}
