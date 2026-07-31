/// Pure domain entity for comments — no framework dependencies.
class CommentEntity {
  // null for top-level comments

  const CommentEntity({
    required this.id,
    required this.videoId,
    required this.userId,
    required this.userName,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
    this.userAvatarUrl = '',
    this.likeCount = 0,
    this.replyCount = 0,
    this.isPinned = false,
    this.isEdited = false,
    this.parentId,
  });
  final String id;
  final String videoId;
  final String userId;
  final String userName;
  final String userAvatarUrl;
  final String text;
  final int likeCount;
  final int replyCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;
  final bool isEdited;
  final String? parentId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommentEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
