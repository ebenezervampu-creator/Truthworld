import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/domain/entities/comment_entity.dart';
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
    this.channelProfilePicUrl,
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
  });

  factory Comment.fromDocumentSnapshot(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    final extractedVideoId =
        (data['videoId'] != null && (data['videoId'] as String).isNotEmpty)
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
    );
  }
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
      // likedBy/dislikedBy maps removed for scale — use subcollection instead
      'isHeartedByCreator': isHeartedByCreator,
      'creatorHeartName': creatorHeartName,
      'donationAmount': donationAmount,
      'donationCurrency': donationCurrency,
      'isDonatedComment': isDonatedComment,
      'donationColorHex': donationColorHex,
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
    String? channelProfilePicUrl,
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
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
      isDislikedByCurrentUser:
          isDislikedByCurrentUser ?? this.isDislikedByCurrentUser,
      isHeartedByCreator: isHeartedByCreator ?? this.isHeartedByCreator,
      creatorHeartName: creatorHeartName ?? this.creatorHeartName,
      donationAmount: donationAmount ?? this.donationAmount,
      donationCurrency: donationCurrency ?? this.donationCurrency,
      isDonatedComment: isDonatedComment ?? this.isDonatedComment,
      donationColorHex: donationColorHex ?? this.donationColorHex,
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
      text: entity.text,
      likeCount: entity.likeCount,
      dislikeCount: 0,
      reportCount: 0,
      createdAt: Timestamp.fromDate(entity.createdAt),
    );
  }
}
