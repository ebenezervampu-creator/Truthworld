/// Pure domain entity for video — no Firestore imports, no framework dependencies.
///
/// This entity represents the core business concept of a video.
/// It is decoupled from data layer models (which handle serialization)
/// and from the presentation layer (which handles UI state).
class VideoEntity {
  const VideoEntity({
    required this.id,
    required this.title,
    required this.ownerId,
    required this.channelId,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.channelName = '',
    this.channelAvatarUrl = '',
    this.thumbnailUrl = '',
    this.originalUrl = '',
    this.hlsUrl = '',
    this.dashUrl = '',
    this.storyboardUrl = '',
    this.storyboardVariants = const [],
    this.viewCount = 0,
    this.likeCount = 0,
    this.dislikeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.duration = Duration.zero,
    this.status = 'ready',
    this.visibility = 'public',
    this.category = '',
    this.tags = const [],
    this.topics = const [],
    this.language = 'en',
    this.isShort = false,
    this.isKidFriendly = true,
    this.enableComments = true,
    this.isMonetized = false,
    this.trustScore = 0.0,
  });
  final String id;
  final String title;
  final String description;

  // Ownership
  final String ownerId;
  final String channelId;
  final String channelName;
  final String channelAvatarUrl;

  // Media
  final String thumbnailUrl;
  final String originalUrl;
  final String hlsUrl;
  final String dashUrl;
  final String storyboardUrl;
  final List<String> storyboardVariants;

  // Engagement
  final int viewCount;
  final int likeCount;
  final int dislikeCount;
  final int commentCount;
  final int shareCount;

  // Metadata
  final Duration duration;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status; // uploading, processing, ready, flagged, deleted
  final String visibility; // public, private, unlisted

  // Content
  final String category;
  final List<String> tags;
  final List<String> topics;
  final String language;
  final bool isShort;
  final bool isKidFriendly;

  // Flags
  final bool enableComments;
  final bool isMonetized;
  final double trustScore;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'VideoEntity(id: $id, title: $title)';
}
