/// Pure domain entity representing a community post.
/// Independent of Firebase and framework dependencies.
class CommunityPostEntity {
  const CommunityPostEntity({
    required this.id,
    required this.title,
    required this.description,
    required this.ownerId,
    required this.channelId,
    required this.channelName,
    required this.channelImage,
    required this.uploadedAt,
    this.selectedCategory = 'General',
    this.visibility = 'Public',
    this.images = const [],
    this.tags = const [],
    this.likes = 0,
    this.dislikes = 0,
    this.dislikeCount = 0,
    this.commentCount = 0,
    this.views = 0,
    this.downloads = 0,
    this.isKidFriendly = false,
    this.processed = false,
    this.isLikeEnabled = true,
    this.showLikeCount = true,
    this.isDislikeEnabled = true,
    this.showDislikeCount = true,
    this.isCommentsEnabled = true,
  });

  final String id;
  final String title;
  final String description;
  final String ownerId;
  final String channelId;
  final String channelName;
  final String channelImage;
  final DateTime uploadedAt;
  final String selectedCategory;
  final String visibility;
  final List<String> images;
  final List<String> tags;
  final int likes;
  final int dislikes;
  final int dislikeCount;
  final int commentCount;
  final int views;
  final int downloads;
  final bool isKidFriendly;
  final bool processed;
  final bool isLikeEnabled;
  final bool showLikeCount;
  final bool isDislikeEnabled;
  final bool showDislikeCount;
  final bool isCommentsEnabled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommunityPostEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
