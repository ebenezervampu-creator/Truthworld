import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/utils/content_validator.dart';
import 'package:truthworld/features/channel/data/models/channel_loyalty_badge.dart';
import 'package:truthworld/features/channel/data/services/channel_memory_cache.dart';

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
    this.channelHandle,
    this.channelProfilePicUrl,
    this.isChannel,
    this.isLikedByCurrentUser = false,
    this.isDislikedByCurrentUser = false,
    this.isMember = false,
    this.memberSince,
    this.memberTierName,
  });

  factory Reply.fromDocumentSnapshot(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    final userProfilePicUrl = () {
      final candidates = [
        data['userProfilePicUrl'],
        data['userAvatar'],
        data['userAvatarUrl'],
        data['avatarUrl'],
        data['photoURL'],
        data['photoUrl'],
        data['authorProfileImageUrl'],
        data['userImage'],
      ];
      for (final item in candidates) {
        if (item is String && item.trim().isNotEmpty) {
          return item.trim();
        }
      }
      return '';
    }();

    final channelHandle = () {
      final candidates = [
        data['channelHandle'],
        data['handle'],
      ];
      for (final item in candidates) {
        if (item is String && item.trim().isNotEmpty) {
          final t = item.trim();
          return t.startsWith('@') ? t : '@$t';
        }
      }
      return null;
    }();

    final channelProfilePicUrl = () {
      final candidates = [
        data['channelProfilePicUrl'],
        data['channelAvatarUrl'],
        data['channelImage'],
        data['channelAvatar'],
        data['avatarUrl'],
        data['photoURL'],
        data['photoUrl'],
      ];
      for (final item in candidates) {
        if (item is String && item.trim().isNotEmpty) {
          return item.trim();
        }
      }
      return null;
    }();

    return Reply(
      id: doc.id,
      commentId: data['commentId'] ?? '',
      videoId: data['videoId'] ?? '',
      userId: data['userId'] ?? '',
      userName: (data['userName'] as String?)?.trim() ??
          (data['displayName'] as String?)?.trim() ??
          (data['name'] as String?)?.trim() ??
          '',
      userProfilePicUrl: userProfilePicUrl,
      channelId: data['channelId'] ?? data['userId'] ?? '',
      channelName: data['channelName'],
      channelHandle: channelHandle,
      channelProfilePicUrl: channelProfilePicUrl,
      isChannel: data['isChannel'] as bool?,
      text: ContentValidator.cleanProfanity(data['text'] ?? ''),
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
  final String? channelHandle; // Channel handle (e.g. @truthworld)
  final String? channelProfilePicUrl; // Channel avatar
  final bool? isChannel;
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

  /// Whether this reply was authored by a channel rather than a personal user profile.
  bool get isChannelAuthor {
    if (isChannel == true) return true;
    if (channelHandle != null && channelHandle!.trim().isNotEmpty) return true;
    if (channelProfilePicUrl != null && channelProfilePicUrl!.trim().isNotEmpty) return true;
    if (channelName != null && channelName!.trim().isNotEmpty && channelName != userName) return true;
    if (channelId.isNotEmpty && ChannelMemoryCache.get(channelId) != null) return true;
    return false;
  }

  String get displayName {
    // For every channel use only channel handle.
    // For every user use their profile name.
    if (isChannelAuthor) {
      final handle = () {
        if (channelHandle != null && channelHandle!.trim().isNotEmpty) {
          return channelHandle!.trim();
        }
        if (channelId.isNotEmpty) {
          final cached = ChannelMemoryCache.get(channelId);
          if (cached != null && cached.handle.trim().isNotEmpty) {
            return cached.handle.trim();
          }
        }
        if (channelName != null && channelName!.trim().isNotEmpty) {
          return channelName!.trim();
        }
        return 'channel';
      }();
      return handle.startsWith('@') ? handle : '@$handle';
    }

    if (userName.trim().isNotEmpty) {
      final name = userName.trim();
      return name.startsWith('@') ? name.substring(1) : name;
    }
    return 'User';
  }

  String get avatarUrl {
    // For every channel use only channel avatar.
    // For every user use their profile avatar.
    if (isChannelAuthor) {
      if (channelProfilePicUrl != null && channelProfilePicUrl!.trim().isNotEmpty) {
        return channelProfilePicUrl!.trim();
      }
      if (channelId.isNotEmpty) {
        final cachedChannel = ChannelMemoryCache.get(channelId);
        if (cachedChannel != null && cachedChannel.avatarUrl.trim().isNotEmpty) {
          return cachedChannel.avatarUrl.trim();
        }
      }
      return userProfilePicUrl;
    }

    return userProfilePicUrl;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'commentId': commentId,
      'videoId': videoId,
      'userId': userId,
      'userName': userName,
      'userProfilePicUrl': userProfilePicUrl,
      'userAvatar': userProfilePicUrl,
      'userAvatarUrl': userProfilePicUrl,
      'channelId': channelId,
      'channelName': channelName,
      'channelHandle': channelHandle ?? (isChannelAuthor ? displayName : null),
      'channelProfilePicUrl': channelProfilePicUrl,
      'isChannel': isChannelAuthor,
      'avatarUrl': avatarUrl,
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
    String? channelHandle,
    String? channelProfilePicUrl,
    bool? isChannel,
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
      channelHandle: channelHandle ?? this.channelHandle,
      channelProfilePicUrl: channelProfilePicUrl ?? this.channelProfilePicUrl,
      isChannel: isChannel ?? this.isChannel,
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
