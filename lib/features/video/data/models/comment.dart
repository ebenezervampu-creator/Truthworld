import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/utils/content_validator.dart';
import 'package:truthworld/domain/entities/comment_entity.dart';
import 'package:truthworld/features/channel/data/models/channel_loyalty_badge.dart';
import 'package:truthworld/features/channel/data/services/channel_memory_cache.dart';
import 'package:truthworld/features/video/data/models/reply.dart';

class Comment {
  Comment({
    required this.id,
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
    this.hasCreatorReply = false,
    this.creatorReply,
    this.isLikedByCurrentUser = false,
    this.isDislikedByCurrentUser = false,
    this.isHeartedByCreator = false,
    this.creatorHeartName,
    this.donationAmount = 0.0,
    this.donationCurrency = r'$',
    this.isDonatedComment = false,
    this.donationColorHex,
    this.isMember = false,
    this.memberSince,
    this.memberTierName,
  });

  factory Comment.fromDocumentSnapshot(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    final pathSegments = doc.reference.path.split('/');
    // When the document is located at videos/{videoId}/comments/{commentId},
    // the authentic parent video ID is always pathSegments[1].
    final isVideoSubcollection =
        pathSegments.length >= 4 && pathSegments[0] == 'videos';
    final parentVideoId = isVideoSubcollection ? pathSegments[1] : '';

    final extractedVideoId = parentVideoId.isNotEmpty
        ? parentVideoId
        : ((data['videoId'] != null && (data['videoId'] as String).isNotEmpty)
            ? data['videoId'] as String
            : (doc.reference.parent.parent?.id ?? ''));

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

    return Comment(
      id: doc.id,
      videoId: extractedVideoId,
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
      hasCreatorReply: data['hasCreatorReply'] ?? false,
      creatorReply: data['creatorReply'] != null
          ? Reply.fromDocumentSnapshot(data['creatorReply'])
          : null,
      // likedBy/dislikedBy are no longer read from Firestore — check subcollection
      isHeartedByCreator: data['isHeartedByCreator'] ?? false,
      creatorHeartName: data['creatorHeartName'],
      donationAmount: (data['donationAmount'] as num?)?.toDouble() ?? 0.0,
      donationCurrency: data['donationCurrency'] ?? r'$',
      isDonatedComment:
          data['isDonatedComment'] ??
          (data['donationAmount'] != null &&
              (data['donationAmount'] as num) > 0),
      donationColorHex: data['donationColorHex'],
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
    );
  }
  final String id;
  final String videoId;
  final String userId;
  final String userName;
  final String userProfilePicUrl;
  final String channelId; // Channel that posted (if applicable)
  final String? channelName; // Channel name (if posted as channel)
  final String? channelHandle; // Channel handle (e.g. @truthworld)
  final String? channelProfilePicUrl; // Channel avatar
  final bool? isChannel;
  final String text;
  final int likeCount;
  final int dislikeCount;
  final int reportCount;
  final Timestamp createdAt;
  final bool hasCreatorReply;
  final Reply? creatorReply;

  // ⚡ SCALE FIX: likedBy/dislikedBy maps removed — they grow unbounded.
  // Like status is now checked via subcollection: comments/{id}/likes/{userId}
  // These local fields are for optimistic UI only (not persisted to Firestore).
  final bool isLikedByCurrentUser;
  final bool isDislikedByCurrentUser;

  // v8.5 Creator Heart
  final bool isHeartedByCreator;
  final String? creatorHeartName;

  // Super Thanks / Donated Comment
  final double donationAmount;
  final String donationCurrency;
  final bool isDonatedComment;
  final String? donationColorHex;

  // Channel Membership & Loyalty Badge (YouTube-style tenure progression)
  final bool isMember;
  final Timestamp? memberSince;
  final String? memberTierName;

  /// Resolves the YouTube-style tenure milestone for this comment author.
  ChannelLoyaltyMilestone? get loyaltyMilestone {
    if (!isMember) return null;
    return ChannelLoyaltyBadge.milestoneFromJoinedAt(memberSince?.toDate());
  }

  /// Whether this comment was authored by a channel rather than a personal user profile.
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
      'hasCreatorReply': hasCreatorReply,
      'creatorReply': creatorReply?.toMap(),
      // likedBy/dislikedBy maps removed for scale — use subcollection instead
      'isHeartedByCreator': isHeartedByCreator,
      'creatorHeartName': creatorHeartName,
      'donationAmount': donationAmount,
      'donationCurrency': donationCurrency,
      'isDonatedComment': isDonatedComment,
      'donationColorHex': donationColorHex,
      'isMember': isMember,
      if (memberSince != null) 'memberSince': memberSince,
      if (memberTierName != null) 'memberTierName': memberTierName,
    };
  }

  Comment copyWith({
    String? id,
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
    bool? hasCreatorReply,
    Reply? creatorReply,
    bool? isLikedByCurrentUser,
    bool? isDislikedByCurrentUser,
    bool? isHeartedByCreator,
    String? creatorHeartName,
    double? donationAmount,
    String? donationCurrency,
    bool? isDonatedComment,
    String? donationColorHex,
    bool? isMember,
    Timestamp? memberSince,
    String? memberTierName,
  }) {
    return Comment(
      id: id ?? this.id,
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
      hasCreatorReply: hasCreatorReply ?? this.hasCreatorReply,
      creatorReply: creatorReply ?? this.creatorReply,
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
      isDislikedByCurrentUser:
          isDislikedByCurrentUser ?? this.isDislikedByCurrentUser,
      isHeartedByCreator: isHeartedByCreator ?? this.isHeartedByCreator,
      creatorHeartName: creatorHeartName ?? this.creatorHeartName,
      donationAmount: donationAmount ?? this.donationAmount,
      donationCurrency: donationCurrency ?? this.donationCurrency,
      isDonatedComment: isDonatedComment ?? this.isDonatedComment,
      donationColorHex: donationColorHex ?? this.donationColorHex,
      isMember: isMember ?? this.isMember,
      memberSince: memberSince ?? this.memberSince,
      memberTierName: memberTierName ?? this.memberTierName,
    );
  }

  /// Converts this data model to a pure domain [CommentEntity].
  CommentEntity toEntity() {
    return CommentEntity(
      id: id,
      videoId: videoId,
      userId: userId,
      userName: userName,
      userAvatarUrl: userProfilePicUrl,
      text: text,
      likeCount: likeCount,
      createdAt: createdAt.toDate(),
      updatedAt: createdAt.toDate(),
    );
  }

  /// Creates a [Comment] data model from a pure domain [CommentEntity].
  static Comment fromEntity(CommentEntity entity) {
    return Comment(
      id: entity.id,
      videoId: entity.videoId,
      userId: entity.userId,
      userName: entity.userName,
      userProfilePicUrl: entity.userAvatarUrl,
      channelId: entity.userId,
      text: ContentValidator.cleanProfanity(entity.text),
      likeCount: entity.likeCount,
      dislikeCount: 0,
      reportCount: 0,
      createdAt: Timestamp.fromDate(entity.createdAt),
    );
  }
}
