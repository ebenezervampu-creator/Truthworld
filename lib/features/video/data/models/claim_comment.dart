import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/features/channel/data/services/channel_memory_cache.dart';

/// Stance of a community deliberation note on a verified fact-check claim.
enum ClaimCommentStance {
  supports,
  disputes,
  context;

  static ClaimCommentStance fromString(String? val) {
    switch (val?.toLowerCase().trim()) {
      case 'supports':
      case 'agree':
      case 'support':
        return ClaimCommentStance.supports;
      case 'disputes':
      case 'disagree':
      case 'dispute':
      case 'contest':
        return ClaimCommentStance.disputes;
      default:
        return ClaimCommentStance.context;
    }
  }

  String get displayName {
    switch (this) {
      case ClaimCommentStance.supports:
        return 'Supports Verdict';
      case ClaimCommentStance.disputes:
        return 'Disputes Verdict';
      case ClaimCommentStance.context:
        return 'Contextual Clarification';
    }
  }

  String get keyName => name;
}

/// 🏛 ClaimComment
///
/// Represents an evidence-backed community deliberation note or comment
/// specifically anchored to a single factual claim in TruthWorld.
class ClaimComment {
  final String id;
  final String videoId;
  final int claimIndex;
  final String claimText;
  final String userId;
  final String userName;
  final String userProfilePicUrl;
  final String channelId;
  final String? channelName;
  final String? channelHandle;
  final String? channelProfilePicUrl;
  final bool? isChannel;
  final String text;
  final String stance; // 'supports' | 'disputes' | 'context'
  final List<String> sourceUrls;
  final int helpfulCount;
  final int unhelpfulCount;
  final List<String> helpfulUserIds;
  final List<String> unhelpfulUserIds;
  final Timestamp createdAt;

  const ClaimComment({
    required this.id,
    required this.videoId,
    required this.claimIndex,
    required this.claimText,
    required this.userId,
    required this.userName,
    required this.userProfilePicUrl,
    required this.channelId,
    required this.text,
    required this.stance,
    required this.createdAt,
    this.channelName,
    this.channelHandle,
    this.channelProfilePicUrl,
    this.isChannel,
    this.sourceUrls = const [],
    this.helpfulCount = 0,
    this.unhelpfulCount = 0,
    this.helpfulUserIds = const [],
    this.unhelpfulUserIds = const [],
  });

  bool get isSupports => stance.toLowerCase() == 'supports';
  bool get isDisputes => stance.toLowerCase() == 'disputes';
  bool get isContext => stance.toLowerCase() == 'context';

  ClaimCommentStance get parsedStance => ClaimCommentStance.fromString(stance);

  bool isHelpfulBy(String uid) => uid.isNotEmpty && helpfulUserIds.contains(uid);
  bool isUnhelpfulBy(String uid) => uid.isNotEmpty && unhelpfulUserIds.contains(uid);

  bool get isChannelAuthor {
    if (isChannel == true) return true;
    if (channelHandle != null && channelHandle!.trim().isNotEmpty) return true;
    if (channelProfilePicUrl != null && channelProfilePicUrl!.trim().isNotEmpty) return true;
    if (channelName != null && channelName!.trim().isNotEmpty && channelName != userName) return true;
    if (channelId.isNotEmpty && ChannelMemoryCache.get(channelId) != null) return true;
    return false;
  }

  String get displayName {
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
    return 'TruthWorld Member';
  }

  String get avatarUrl {
    if (isChannelAuthor) {
      if (channelProfilePicUrl != null && channelProfilePicUrl!.trim().isNotEmpty) {
        return channelProfilePicUrl!.trim();
      }
      if (channelId.isNotEmpty) {
        final cached = ChannelMemoryCache.get(channelId);
        if (cached != null && cached.avatarUrl.trim().isNotEmpty) {
          return cached.avatarUrl.trim();
        }
      }
      return userProfilePicUrl;
    }
    return userProfilePicUrl;
  }

  factory ClaimComment.fromDocumentSnapshot(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};

    final rawSources = data['sourceUrls'] ?? data['sources'];
    final parsedSources = <String>[];
    if (rawSources is List) {
      for (final item in rawSources) {
        if (item is String && item.trim().isNotEmpty) {
          parsedSources.add(item.trim());
        }
      }
    }

    final rawHelpfulUsers = data['helpfulUserIds'];
    final parsedHelpfulUsers = <String>[];
    if (rawHelpfulUsers is List) {
      for (final item in rawHelpfulUsers) {
        if (item is String && item.isNotEmpty) {
          parsedHelpfulUsers.add(item);
        }
      }
    }

    final rawUnhelpfulUsers = data['unhelpfulUserIds'];
    final parsedUnhelpfulUsers = <String>[];
    if (rawUnhelpfulUsers is List) {
      for (final item in rawUnhelpfulUsers) {
        if (item is String && item.isNotEmpty) {
          parsedUnhelpfulUsers.add(item);
        }
      }
    }

    var createdDateTime = DateTime.now();
    final rawCreatedAt = data['createdAt'];
    if (rawCreatedAt is Timestamp) {
      createdDateTime = rawCreatedAt.toDate();
    } else if (rawCreatedAt is String) {
      createdDateTime = DateTime.tryParse(rawCreatedAt) ?? DateTime.now();
    }

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
      ];
      for (final item in candidates) {
        if (item is String && item.trim().isNotEmpty) {
          return item.trim();
        }
      }
      return null;
    }();

    return ClaimComment(
      id: doc.id,
      videoId: data['videoId'] as String? ?? '',
      claimIndex: (data['claimIndex'] as num?)?.toInt() ?? 0,
      claimText: data['claimText'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      userName: (data['userName'] as String?)?.trim() ??
          (data['displayName'] as String?)?.trim() ??
          'TruthWorld Member',
      userProfilePicUrl: (data['userProfilePicUrl'] as String?)?.trim() ??
          (data['userAvatar'] as String?)?.trim() ??
          (data['avatarUrl'] as String?)?.trim() ??
          '',
      channelId: data['channelId'] as String? ?? data['userId'] as String? ?? '',
      channelName: data['channelName'] as String?,
      channelHandle: channelHandle,
      channelProfilePicUrl: channelProfilePicUrl,
      isChannel: data['isChannel'] as bool?,
      text: data['text'] as String? ?? '',
      stance: (data['stance'] as String?)?.toLowerCase().trim() ?? 'context',
      sourceUrls: parsedSources,
      helpfulCount: (data['helpfulCount'] as num?)?.toInt() ?? parsedHelpfulUsers.length,
      unhelpfulCount: (data['unhelpfulCount'] as num?)?.toInt() ?? parsedUnhelpfulUsers.length,
      helpfulUserIds: parsedHelpfulUsers,
      unhelpfulUserIds: parsedUnhelpfulUsers,
      createdAt: Timestamp.fromDate(createdDateTime),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'videoId': videoId,
      'claimIndex': claimIndex,
      'claimText': claimText,
      'userId': userId,
      'userName': userName,
      'userProfilePicUrl': userProfilePicUrl,
      'channelId': channelId,
      if (channelName != null && channelName!.isNotEmpty) 'channelName': channelName,
      if (channelHandle != null && channelHandle!.isNotEmpty) 'channelHandle': channelHandle,
      if (channelProfilePicUrl != null && channelProfilePicUrl!.isNotEmpty) 'channelProfilePicUrl': channelProfilePicUrl,
      'isChannel': isChannelAuthor,
      'text': text,
      'stance': stance,
      'sourceUrls': sourceUrls,
      'helpfulCount': helpfulCount,
      'unhelpfulCount': unhelpfulCount,
      'helpfulUserIds': helpfulUserIds,
      'unhelpfulUserIds': unhelpfulUserIds,
      'createdAt': createdAt,
    };
  }

  ClaimComment copyWith({
    String? id,
    String? videoId,
    int? claimIndex,
    String? claimText,
    String? userId,
    String? userName,
    String? userProfilePicUrl,
    String? channelId,
    String? channelName,
    String? text,
    String? stance,
    List<String>? sourceUrls,
    int? helpfulCount,
    int? unhelpfulCount,
    List<String>? helpfulUserIds,
    List<String>? unhelpfulUserIds,
    Timestamp? createdAt,
  }) {
    return ClaimComment(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      claimIndex: claimIndex ?? this.claimIndex,
      claimText: claimText ?? this.claimText,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userProfilePicUrl: userProfilePicUrl ?? this.userProfilePicUrl,
      channelId: channelId ?? this.channelId,
      channelName: channelName ?? this.channelName,
      text: text ?? this.text,
      stance: stance ?? this.stance,
      sourceUrls: sourceUrls ?? this.sourceUrls,
      helpfulCount: helpfulCount ?? this.helpfulCount,
      unhelpfulCount: unhelpfulCount ?? this.unhelpfulCount,
      helpfulUserIds: helpfulUserIds ?? this.helpfulUserIds,
      unhelpfulUserIds: unhelpfulUserIds ?? this.unhelpfulUserIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
