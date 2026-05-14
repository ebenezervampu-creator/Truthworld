import 'package:cloud_firestore/cloud_firestore.dart';

/// Tracks a user's interaction state with a comment (or reply)
class CommentInteraction {
  final String id; // Unique: "${userId}_${commentId}_${source}"
  final String commentId;
  final String? replyId; // Null if interaction is on comment
  final String videoId;
  final String userId;
  final bool isLiked;
  final bool isDisliked;
  final bool likeAsChannel; // True if liking as channel, false if liking as self
  final Timestamp createdAt;
  final Timestamp? updatedAt;

  CommentInteraction({
    required this.id,
    required this.commentId,
    this.replyId,
    required this.videoId,
    required this.userId,
    required this.isLiked,
    required this.isDisliked,
    required this.likeAsChannel,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'commentId': commentId,
      'replyId': replyId,
      'videoId': videoId,
      'userId': userId,
      'isLiked': isLiked,
      'isDisliked': isDisliked,
      'likeAsChannel': likeAsChannel,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory CommentInteraction.fromDocumentSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommentInteraction(
      id: doc.id,
      commentId: data['commentId'] ?? '',
      replyId: data['replyId'],
      videoId: data['videoId'] ?? '',
      userId: data['userId'] ?? '',
      isLiked: data['isLiked'] ?? false,
      isDisliked: data['isDisliked'] ?? false,
      likeAsChannel: data['likeAsChannel'] ?? false,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'],
    );
  }

  CommentInteraction copyWith({
    String? id,
    String? commentId,
    String? replyId,
    String? videoId,
    String? userId,
    bool? isLiked,
    bool? isDisliked,
    bool? likeAsChannel,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return CommentInteraction(
      id: id ?? this.id,
      commentId: commentId ?? this.commentId,
      replyId: replyId ?? this.replyId,
      videoId: videoId ?? this.videoId,
      userId: userId ?? this.userId,
      isLiked: isLiked ?? this.isLiked,
      isDisliked: isDisliked ?? this.isDisliked,
      likeAsChannel: likeAsChannel ?? this.likeAsChannel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt ?? Timestamp.now(),
    );
  }
}





