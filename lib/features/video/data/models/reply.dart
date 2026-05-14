import 'package:cloud_firestore/cloud_firestore.dart';

class Reply {
  final String id;
  final String commentId;
  final String videoId;
  final String userId;
  final String userName;
  final String userProfilePicUrl;
  final String channelId; // Channel that replied (if applicable)
  final String? channelName; // Channel name (if replied as channel)
  final String? channelProfilePicUrl; // Channel avatar
  final String text;
  final int likeCount;
  final int dislikeCount;
  final int reportCount;
  final Timestamp createdAt;
  
  // Tracking likes: Map<userId_source, bool> where source = "user" or "channel"
  final Map<String, bool> likedBy;
  final Map<String, bool> dislikedBy;

  Reply({
    required this.id,
    required this.commentId,
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
    this.likedBy = const {},
    this.dislikedBy = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'commentId': commentId,
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
      'likedBy': likedBy,
      'dislikedBy': dislikedBy,
    };
  }

  factory Reply.fromDocumentSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Reply(
      id: doc.id,
      commentId: data['commentId'] ?? '',
      videoId: data['videoId'] ?? '',
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
      likedBy: Map<String, bool>.from(data['likedBy'] ?? {}),
      dislikedBy: Map<String, bool>.from(data['dislikedBy'] ?? {}),
    );
  }

  Reply copyWith({
    String? id,
    String? commentId,
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
    Map<String, bool>? likedBy,
    Map<String, bool>? dislikedBy,
  }) {
    return Reply(
      id: id ?? this.id,
      commentId: commentId ?? this.commentId,
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
      likedBy: likedBy ?? this.likedBy,
      dislikedBy: dislikedBy ?? this.dislikedBy,
    );
  }
}





