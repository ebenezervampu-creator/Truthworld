import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/features/channel/data/models/channel_loyalty_badge.dart';

class Reply {
  Reply({
    required this.id,
    required this.commentId,
    required this.videoId,
    required this.userId,
    required this.userName,
    required this.userProfilePicUrl,
    required this.channelId,
    required this.text,
    required this.likeCount,
    required this.dislikeCount,
    required this.reportCount,
    required this.createdAt,
    this.channelName,
    this.channelProfilePicUrl,
    this.isLikedByCurrentUser = false,
    this.isDislikedByCurrentUser = false,
    this.isMember = false,
    this.memberSince,
    this.memberTierName,
  });

  factory Reply.fromDocumentSnapshot(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
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
      isMember: (data['isMember'] as bool?) ?? (data['memberSince'] != null),
      memberSince: data['memberSince'] is Timestamp
          ? data['memberSince'] as Timestamp
          : (data['memberSince'] != null
              ? Timestamp.fromDate(
                  DateTime.tryParse(data['memberSince'].toString()) ??
                      DateTime.now(),
                )
              : null),
      memberTierName: data['memberTierName'] as String?,
      // likedBy/dislikedBy not read from Firestore — use subcollection
    );
  }
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

  // ⚡ SCALE FIX: likedBy/dislikedBy maps removed — use subcollection pattern
  final bool isLikedByCurrentUser;
  final bool isDislikedByCurrentUser;

  // Channel Membership & Loyalty Badge (YouTube-style tenure progression)
  final bool isMember;
  final Timestamp? memberSince;
  final String? memberTierName;

  /// Resolves the YouTube-style tenure milestone for this reply author.
  ChannelLoyaltyMilestone? get loyaltyMilestone {
    if (!isMember) return null;
    return ChannelLoyaltyBadge.milestoneFromJoinedAt(memberSince?.toDate());
  }

  String get displayName {
    if (channelName != null && channelName!.isNotEmpty) {
      return channelName!.startsWith('@') ? channelName! : '@$channelName';
    }
    return userName;
  }

  String get avatarUrl =>
      (channelProfilePicUrl != null && channelProfilePicUrl!.isNotEmpty)
      ? channelProfilePicUrl!
      : userProfilePicUrl;

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
      'isMember': isMember,
      if (memberSince != null) 'memberSince': memberSince,
      if (memberTierName != null) 'memberTierName': memberTierName,
      // likedBy/dislikedBy maps removed for scale
    };
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
    bool? isLikedByCurrentUser,
    bool? isDislikedByCurrentUser,
    bool? isMember,
    Timestamp? memberSince,
    String? memberTierName,
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
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
      isDislikedByCurrentUser:
          isDislikedByCurrentUser ?? this.isDislikedByCurrentUser,
      isMember: isMember ?? this.isMember,
      memberSince: memberSince ?? this.memberSince,
      memberTierName: memberTierName ?? this.memberTierName,
    );
  }
}
