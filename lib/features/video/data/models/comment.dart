import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/features/video/data/models/reply.dart';

class Comment {
  final String id;
  final String videoId;
  final String userId;
  final String userName;
  final String userProfilePicUrl;
  final String channelId; // Channel that posted (if applicable)
  final String? channelName; // Channel name (if posted as channel)
  final String? channelProfilePicUrl; // Channel avatar
  final String text;
  final int likeCount;
  final int dislikeCount;
  final int reportCount;
  final Timestamp createdAt;
  final bool hasCreatorReply;
  final Reply? creatorReply;
  
  // Tracking likes: Map<userId_source, bool> where source = "user" or "channel"
  final Map<String, bool> likedBy;
  final Map<String, bool> dislikedBy;

  // v8.5 Creator Heart
  final bool isHeartedByCreator;
  final String? creatorHeartName;

  Comment({
    required this.id,
    required this.videoId,
    required this.userId,
    required this.userName,
    required this.userProfilePicUrl,
    required this.channelId,
    this.channelName,
    this.channelProfilePicUrl,
    required this.text,
    required this.likeCount,
    required this.dislikeCount,
    required this.reportCount,
    required this.createdAt,
    this.hasCreatorReply = false,
    this.creatorReply,
    this.likedBy = const {},
    this.dislikedBy = const {},
    this.isHeartedByCreator = false,
    this.creatorHeartName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'videoId': videoId,
      'userId': userId,
      'userName': userName,
      'userProfilePicUrl': userProfilePicUrl,
      'channelId': channelId,
      'channelName': channelName,
      'channelProfilePicUrl': channelProfilePicUrl,
      'text': text,
      'likeCount': likeCount,
      'dislikeCount': dislikeCount,
      'reportCount': reportCount,
      'createdAt': createdAt,
      'hasCreatorReply': hasCreatorReply,
      'creatorReply': creatorReply?.toMap(),
      'likedBy': likedBy,
      'dislikedBy': dislikedBy,
      'isHeartedByCreator': isHeartedByCreator,
      'creatorHeartName': creatorHeartName,
    };
  }

  factory Comment.fromDocumentSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final extractedVideoId = (data['videoId'] != null && (data['videoId'] as String).isNotEmpty)
        ? data['videoId'] as String
        : (doc.reference.parent.parent?.id ?? '');

    return Comment(
      id: doc.id,
      videoId: extractedVideoId,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userProfilePicUrl: data['userProfilePicUrl'] ?? '',
      channelId: data['channelId'] ?? data['userId'] ?? '',
      channelName: data['channelName'],
      channelProfilePicUrl: data['channelProfilePicUrl'],
      text: data['text'] ?? '',
      likeCount: data['likeCount'] ?? 0,
      dislikeCount: data['dislikeCount'] ?? 0,
      reportCount: data['reportCount'] ?? 0,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      hasCreatorReply: data['hasCreatorReply'] ?? false,
      creatorReply: data['creatorReply'] != null
          ? Reply.fromDocumentSnapshot(data['creatorReply'])
          : null,
      likedBy: Map<String, bool>.from(data['likedBy'] ?? {}),
      dislikedBy: Map<String, bool>.from(data['dislikedBy'] ?? {}),
      isHeartedByCreator: data['isHeartedByCreator'] ?? false,
      creatorHeartName: data['creatorHeartName'],
    );
  }

  Comment copyWith({
    String? id,
    String? videoId,
    String? userId,
    String? userName,
    String? userProfilePicUrl,
    String? channelId,
    String? channelName,
    String? channelProfilePicUrl,
    String? text,
    int? likeCount,
    int? dislikeCount,
    int? reportCount,
    Timestamp? createdAt,
    bool? hasCreatorReply,
    Reply? creatorReply,
    Map<String, bool>? likedBy,
    Map<String, bool>? dislikedBy,
    bool? isHeartedByCreator,
    String? creatorHeartName,
  }) {
    return Comment(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userProfilePicUrl: userProfilePicUrl ?? this.userProfilePicUrl,
      channelId: channelId ?? this.channelId,
      channelName: channelName ?? this.channelName,
      channelProfilePicUrl: channelProfilePicUrl ?? this.channelProfilePicUrl,
      text: text ?? this.text,
      likeCount: likeCount ?? this.likeCount,
      dislikeCount: dislikeCount ?? this.dislikeCount,
      reportCount: reportCount ?? this.reportCount,
      createdAt: createdAt ?? this.createdAt,
      hasCreatorReply: hasCreatorReply ?? this.hasCreatorReply,
      creatorReply: creatorReply ?? this.creatorReply,
      likedBy: likedBy ?? this.likedBy,
      dislikedBy: dislikedBy ?? this.dislikedBy,
      isHeartedByCreator: isHeartedByCreator ?? this.isHeartedByCreator,
      creatorHeartName: creatorHeartName ?? this.creatorHeartName,
    );
  }
}





