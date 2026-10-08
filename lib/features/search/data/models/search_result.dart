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
    this.language,
    this.category,
    this.visibility = 'public',
  });

  /// Convert Firestore document to SearchResult
  factory SearchResult.fromFirestore(
    DocumentSnapshot doc, {
    ResultType type = ResultType.video,
  }) {
    final data = doc.data()! as Map<String, dynamic>;

    String firstNonEmpty(List<dynamic> items) {
      for (final item in items) {
        if (item is String && item.trim().isNotEmpty) {
          return item.trim();
        }
      }
      return '';
    }

    switch (type) {
      case ResultType.channel:
        final channelTitle = firstNonEmpty([
          data['channelName'],
          data['name'],
          data['displayName'],
        ]);
        final finalTitle = channelTitle.isNotEmpty ? channelTitle : 'Channel';

        final avatar = firstNonEmpty([
          data['avatarUrl'],
          data['avatarImage'],
          data['channelAvatarUrl'],
          data['channelImage'],
          data['photoUrl'],
          data['photoURL'],
          data['profileImageUrl'],
          data['avatar'],
          data['imageUrl'],
        ]);
        final subs = (data['subscriberCount'] as num?)?.toInt() ??
            (data['subscribers'] as num?)?.toInt() ??
            (data['subscriber_count'] as num?)?.toInt() ??
            0;
        final handle = firstNonEmpty([
          data['handle'],
          data['channelHandle'],
          data['customUrl'],
        ]);

        return SearchResult(
          id: doc.id,
          title: finalTitle,
          thumbnail: avatar,
          views: subs,
          channelName: handle.isNotEmpty
              ? (handle.startsWith('@') ? handle : '@$handle')
              : finalTitle,
          channelImage: avatar,
          createdAt: TimestampUtils.parse(data['createdAt']),
          type: ResultType.channel,
          language: data['language'] as String?,
          category: data['category'] as String?,
        );
      case ResultType.playlist:
        final playlistTitle = firstNonEmpty([
          data['name'],
          data['playlistName'],
          data['title'],
        ]);
        final playlistThumb = firstNonEmpty([
          data['thumbnailUrl'],
          data['thumbnail'],
          data['coverUrl'],
        ]);
        final vidCount = (data['videoCount'] as num?)?.toInt() ??
            (data['videosCount'] as num?)?.toInt() ??
            (data['videoIds'] as List?)?.length ??
            0;
        final creator = firstNonEmpty([
          data['creatorName'],
          data['channelName'],
          data['ownerName'],
        ]);

        return SearchResult(
          id: doc.id,
          title: playlistTitle,
          thumbnail: playlistThumb,
          views: vidCount,
          channelName: creator.isNotEmpty ? creator : 'Truthworld',
          channelImage: '',
          createdAt: TimestampUtils.parse(data['createdAt']),
          type: ResultType.playlist,
          category: data['category'] as String?,
        );
      case ResultType.topic:
        final slugVal = (data['slug'] as String?)?.trim() ?? '';
        final rawTitle = firstNonEmpty([
          data['title'],
          data['name'],
          data['topicName'],
        ]);
        final topicTitle = rawTitle.isNotEmpty
            ? rawTitle
            : (slugVal.isNotEmpty && slugVal.toLowerCase() != 'topic'
                ? slugVal.replaceAll('-', ' ')
                : '');
        final topicThumb = firstNonEmpty([
          data['thumbnailUrl'],
          data['thumbnail'],
          data['coverImage'],
          data['imageUrl'],
        ]);
        final topicCount = (data['videoCount'] as num?)?.toInt() ??
            (data['featuredVideoIds'] as List?)?.length ??
            0;
        final handleVal = (data['handle'] as String?)?.trim() ??
            (slugVal.isNotEmpty ? 'T/$slugVal' : '');

        return SearchResult(
          id: doc.id,
          title: topicTitle,
          thumbnail: topicThumb,
          views: topicCount,
          channelName: handleVal,
          channelImage: '',
          createdAt: TimestampUtils.parse(data['createdAt']),
          type: ResultType.topic,
          category: data['category'] as String?,
        );
      case ResultType.video:
        final mediaMap = data['media'] is Map ? data['media'] as Map : null;
        final videoThumbnail = firstNonEmpty([
          data['thumbnailUrl'],
          data['thumbnail'],
          mediaMap?['thumbnailUrl'],
          mediaMap?['thumbnail'],
        ]);
        final rawTitle = firstNonEmpty([
          data['title'],
          data['vTitle'],
        ]);
        final chName = firstNonEmpty([
          data['channelName'],
          data['ownerName'],
          data['creatorName'],
        ]);
        final chImage = firstNonEmpty([
          data['channelImage'],
          data['channelAvatarUrl'],
          data['channelImageUrl'],
          data['avatarUrl'],
          data['avatarImage'],
          data['ownerAvatarUrl'],
          data['creatorAvatarUrl'],
          data['photoUrl'],
          data['photoURL'],
        ]);

        return SearchResult(
          id: doc.id,
          title: rawTitle.isNotEmpty ? rawTitle : 'Untitled',
          thumbnail: videoThumbnail,
          views: (data['viewCount'] as num?)?.toInt() ??
              (data['views'] as num?)?.toInt() ??
              (data['stats'] is Map
                  ? (data['stats']['views'] as num?)?.toInt()
                  : null) ??
              0,
          channelName: chName.isNotEmpty ? chName : 'Unknown',
          channelImage: chImage,
          createdAt: TimestampUtils.parse(
            data['uploadedAt'] ?? data['createdAt'] ?? data['uploadDate'] ?? data['publishedAt'],
          ),
          durationMs: (data['durationMs'] as num?)?.toInt() ??
              ((data['duration'] as num?) != null
                  ? ((data['duration'] as num).toInt() * 1000)
                  : null),
          language: data['language'] as String?,
          category: data['category'] as String?,
          visibility: (data['visibility'] as String?) ?? 'public',
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
        (e) =>
            e.toString() == (map['type'] as String?) ||
            e.name == (map['type'] as String?),
        orElse: () => ResultType.video,
      ),
      durationMs: (map['durationMs'] as num?)?.toInt(),
      language: map['language'] as String?,
      category: map['category'] as String?,
      visibility: map['visibility'] as String? ?? 'public',
      relevanceScore:
          (map['relevanceScore'] as num?)?.toDouble() ?? 0.0,
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
  final String? language;
  final String? category;
  final String visibility;
  double relevanceScore;

  // Getters for compatibility with EnhancedSearchController
  int get viewCount => views;
  DateTime get uploadedAt => createdAt.toDate();
  int? get duration => durationMs != null ? (durationMs! ~/ 1000) : null;
  String? get quality =>
      null; // SearchResult is lightweight, quality might not be present
  int? get videoCount =>
      type == ResultType.playlist || type == ResultType.topic ? views : null;
  bool get isPrivate =>
      visibility.trim().toLowerCase() == 'private' ||
      visibility.trim().toLowerCase() == 'private_draft';

  bool get isValid {
    final t = title.trim().toLowerCase();
    if (t.isEmpty) return false;
    if (type == ResultType.video) {
      final vis = visibility.trim().toLowerCase();
      if (vis == 'private' || vis == 'private_draft' || vis == 'draft') {
        return false;
      }
      if (t == 'untitled' ||
          t == 'untitled video' ||
          t == 'untitled draft' ||
          t == 'uploading...' ||
          t.startsWith('untitled draft') ||
          t.startsWith('uploading')) {
        return false;
      }
    } else if (type == ResultType.playlist) {
      if (t == 'playlist' ||
          t == 'untitled' ||
          t == 'untitled playlist' ||
          t == 'truthworld playlist' ||
          t.startsWith('untitled')) {
        return false;
      }
      // Playlists must have at least 1 video to be displayed in search
      if (views <= 0) {
        return false;
      }
    } else if (type == ResultType.topic) {
      if (t == 'topic' ||
          t == 'featured topic' ||
          t == 'untitled' ||
          t == 'untitled topic' ||
          t.startsWith('untitled')) {
        return false;
      }
      // Topics must have at least 1 video to be displayed in search
      if (views <= 0) {
        return false;
      }
    } else if (type == ResultType.channel) {
      if (t == 'channel' ||
          t == 'untitled' ||
          t == 'untitled channel' ||
          t.startsWith('untitled')) {
        return false;
      }
    }
    return true;
  }

  /// Convert to map for serialization and caching
  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'thumbnail': thumbnail,
    'views': views,
    'channelName': channelName,
    'channelImage': channelImage,
    'createdAt': createdAt.toDate().toIso8601String(),
    'type': type.toString(),
    'durationMs': durationMs,
    'language': language,
    'category': category,
    'visibility': visibility,
  };

  @override
  String toString() => 'SearchResult($type: $id, title: $title, views: $views)';
}
