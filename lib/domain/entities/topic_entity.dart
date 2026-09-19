/// Pure domain entity representing a topic or knowledge hub.
/// Independent of Firebase and framework dependencies.
class TopicEntity {
  const TopicEntity({
    required this.id,
    required this.title,
    required this.slug,
    required this.handle,
    required this.description,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
    this.thumbnailUrl,
    this.coverImage,
    this.videoCount = 0,
    this.postCount = 0,
    this.followerCount = 0,
    this.views = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    this.trendingScore = 0.0,
    this.status = 'active',
    this.channelId,
    this.creatorId,
    this.tags = const [],
    this.featuredVideoIds = const [],
    this.relatedTopics = const [],
  });

  final String id;
  final String title;
  final String slug;
  final String handle;
  final String description;
  final String category;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? thumbnailUrl;
  final String? coverImage;
  final int videoCount;
  final int postCount;
  final int followerCount;
  final int views;
  final int likeCount;
  final int commentCount;
  final double trendingScore;
  final String status;
  final String? channelId;
  final String? creatorId;
  final List<String> tags;
  final List<String> featuredVideoIds;
  final List<String> relatedTopics;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopicEntity && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
