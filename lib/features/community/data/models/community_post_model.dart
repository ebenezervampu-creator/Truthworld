import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/domain/entities/community_post_entity.dart';
import 'package:truthworld/features/community/data/models/poll_model.dart';

/// Data model for a community post with multi-image and optional poll support.
class CommunityPostModel {
  const CommunityPostModel({
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
    this.status = 'published',
    this.deletionRequestedAt,
    this.images = const [],
    this.tags = const [],
    this.poll,
    this.scheduledTime,
    this.likes = 0,
    this.dislikes = 0,
    this.dislikeCount = 0,
    this.commentCount = 0,
    this.views = 0,
    this.downloads = 0,
    this.likedBy = const [],
    this.dislikedBy = const [],
    this.shares = const [],
    this.isKidFriendly = false,
    this.processed = false,
    this.isLikeEnabled = true,
    this.showLikeCount = true,
    this.isDislikeEnabled = true,
    this.showDislikeCount = true,
    this.isCommentsEnabled = true,
    this.isChannelTrusted = false,
  });

  factory CommunityPostModel.fromMap(Map<String, dynamic> map) {
    // Support both 'images' array and legacy single 'image' field
    var imageList = <String>[];
    if (map['images'] != null) {
      if (map['images'] is List) {
        imageList = (map['images'] as List)
            .map((e) => e?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
      } else if (map['images'] is String && (map['images'] as String).isNotEmpty) {
        imageList = [map['images'] as String];
      }
    } else if (map['image'] != null && (map['image'] as String).isNotEmpty) {
      imageList = [map['image'] as String];
    }

    var rawTitle = (map['title'] as String?)?.trim() ?? '';
    final desc = (map['description'] as String?)?.trim() ?? '';
    if (rawTitle.isEmpty || rawTitle.toLowerCase().startsWith('untitled')) {
      rawTitle = desc.isNotEmpty
          ? (desc.length > 50 ? '${desc.substring(0, 47)}...' : desc)
          : 'Community Post';
    }
    final chName = (map['channelName'] as String?)?.trim() ?? '';

    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    int parseInt(dynamic val) {
      if (val == null) return 0;
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? 0;
      return 0;
    }

    List<String> parseStringList(dynamic val) {
      if (val == null) return [];
      if (val is List) {
        return val.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
      }
      if (val is String && val.isNotEmpty) return [val];
      return [];
    }

    final uploadedDate = parseDate(
      map['uploadedAt'] ?? map['timestamp'] ?? map['createdAt'] ?? map['created_at'],
    );
    final scheduledDate = map['scheduledTime'] != null ? parseDate(map['scheduledTime']) : null;

    return CommunityPostModel(
      id: map['id']?.toString() ?? '',
      title: rawTitle,
      description: desc,
      ownerId: (map['ownerId'] ?? map['userId'] ?? '').toString(),
      channelId: (map['channelId'] ?? '').toString(),
      channelName: chName.isNotEmpty ? chName : 'Truthworld Creator',
      channelImage: (map['channelImage'] ?? map['channelAvatarUrl'] ?? map['avatarUrl'] ?? '').toString(),
      selectedCategory: (map['selectedCategory'] ?? map['category'] ?? 'General').toString(),
      visibility: (map['visibility'] ?? 'Public').toString(),
      status: (map['status'] ?? 'published').toString(),
      deletionRequestedAt: map['deletionRequestedAt'] != null ? parseDate(map['deletionRequestedAt']) : null,
      images: imageList,
      tags: parseStringList(map['tags']),
      poll: map['poll'] != null
          ? PollModel.fromMap(Map<String, dynamic>.from(map['poll'] as Map))
          : null,
      uploadedAt: uploadedDate,
      scheduledTime: scheduledDate,
      likes: parseInt(map['likes']),
      dislikes: parseInt(map['dislikes']),
      dislikeCount: parseInt(map['dislikeCount']),
      commentCount: parseInt(map['commentCount']),
      views: parseInt(map['views']),
      downloads: parseInt(map['downloads']),
      likedBy: () {
        final listA = parseStringList(map['likedBy']);
        final listB = parseStringList(map['likedby']);
        return <String>{...listA, ...listB}.toList();
      }(),
      dislikedBy: () {
        final listA = parseStringList(map['dislikedBy']);
        final listB = parseStringList(map['dislikedby']);
        return <String>{...listA, ...listB}.toList();
      }(),
      shares: parseStringList(map['shares']),
      isKidFriendly: map['isKidFriendly'] == true,
      processed: map['processed'] == true,
      isLikeEnabled: map['isLikeEnabled'] != false,
      showLikeCount: map['showLikeCount'] != false && map['showLikesCount'] != false,
      isDislikeEnabled: map['isDislikeEnabled'] != false,
      showDislikeCount: map['showDislikeCount'] != false && map['showDislikesCount'] != false,
      isCommentsEnabled: map['isCommentsEnabled'] != false,
      isChannelTrusted: (map['channelTrustedModerationBypass'] as bool?) ??
          (map['isChannelTrusted'] as bool?) ??
          (map['trustedModerationBypass'] as bool?) ??
          false,
    );
  }
  final bool isChannelTrusted;
  /// Blue Checkmark badges are completely discontinued platform-wide for channels.
  bool get showVerifiedBadge => false;
  final String id;
  final String title;
  final String description;
  final String ownerId;
  final String channelId;
  final String channelName;
  final String channelImage;
  final String selectedCategory;
  final String visibility;
  final String status;
  final DateTime? deletionRequestedAt;
  final List<String> images;
  final List<String> tags;
  final PollModel? poll;
  final DateTime uploadedAt;
  final DateTime? scheduledTime;
  final int likes;
  final int dislikes;
  final int dislikeCount;
  final int commentCount;
  final int views;
  final int downloads;
  final List<String> likedBy;
  final List<String> dislikedBy;
  final List<String> shares;
  final bool isKidFriendly;
  final bool processed;
  final bool isLikeEnabled;
  final bool showLikeCount;
  final bool isDislikeEnabled;
  final bool showDislikeCount;
  final bool isCommentsEnabled;

  bool get isDeleted =>
      status == 'deleted' ||
      status == 'deletion_pending' ||
      status == 'trashed';

  bool get isOnHold =>
      status.toLowerCase() == 'onhold' ||
      status.toLowerCase() == 'hold' ||
      status.toLowerCase() == 'on_hold';

  bool get isDraft {
    final vis = visibility.trim().toLowerCase();
    final cat = selectedCategory.trim().toLowerCase();
    final t = title.trim().toLowerCase();
    final s = status.trim().toLowerCase();
    if (s == 'draft' || vis == 'draft' || cat == 'draft' || t == 'uploading...') {
      return true;
    }
    return false;
  }

  bool get isValid => id.isNotEmpty && !isDraft && !isDeleted && !isOnHold;

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'ownerId': ownerId,
    'channelId': channelId,
    'channelName': channelName,
    'channelImage': channelImage,
    'selectedCategory': selectedCategory,
    'visibility': visibility,
    'status': status,
    if (deletionRequestedAt != null)
      'deletionRequestedAt': Timestamp.fromDate(deletionRequestedAt!),
    'images': images,
    // Keep backward-compatible 'image' field (first image or empty)
    'image': images.isNotEmpty ? images.first : '',
    'tags': tags,
    if (poll != null) 'poll': poll!.toMap(),
    'uploadedAt': Timestamp.fromDate(uploadedAt),
    if (scheduledTime != null)
      'scheduledTime': Timestamp.fromDate(scheduledTime!),
    'likes': likes,
    'dislikes': dislikes,
    'dislikeCount': dislikeCount,
    'commentCount': commentCount,
    'views': views,
    'downloads': downloads,
    'likedby': likedBy,
    'likedBy': likedBy,
    'dislikedby': dislikedBy,
    'dislikedBy': dislikedBy,
    'shares': shares,
    'isKidFriendly': isKidFriendly,
    'processed': processed,
    'isLikeEnabled': isLikeEnabled,
    'showLikeCount': showLikeCount,
    'isDislikeEnabled': isDislikeEnabled,
    'showDislikeCount': showDislikeCount,
    'isCommentsEnabled': isCommentsEnabled,
  };

  /// Converts this data model to a pure domain [CommunityPostEntity].
  CommunityPostEntity toEntity() {
    return CommunityPostEntity(
      id: id,
      title: title,
      description: description,
      ownerId: ownerId,
      channelId: channelId,
      channelName: channelName,
      channelImage: channelImage,
      uploadedAt: uploadedAt,
      selectedCategory: selectedCategory,
      visibility: visibility,
      images: images,
      tags: tags,
      likes: likes,
      dislikes: dislikes,
      dislikeCount: dislikeCount,
      commentCount: commentCount,
      views: views,
      downloads: downloads,
      isKidFriendly: isKidFriendly,
      processed: processed,
      isLikeEnabled: isLikeEnabled,
      showLikeCount: showLikeCount,
      isDislikeEnabled: isDislikeEnabled,
      showDislikeCount: showDislikeCount,
      isCommentsEnabled: isCommentsEnabled,
    );
  }

  /// Creates a [CommunityPostModel] data model from a pure domain [CommunityPostEntity].
  static CommunityPostModel fromEntity(CommunityPostEntity entity) {
    return CommunityPostModel(
      id: entity.id,
      title: entity.title,
      description: entity.description,
      ownerId: entity.ownerId,
      channelId: entity.channelId,
      channelName: entity.channelName,
      channelImage: entity.channelImage,
      uploadedAt: entity.uploadedAt,
      selectedCategory: entity.selectedCategory,
      visibility: entity.visibility,
      images: entity.images,
      tags: entity.tags,
      likes: entity.likes,
      dislikes: entity.dislikes,
      dislikeCount: entity.dislikeCount,
      commentCount: entity.commentCount,
      views: entity.views,
      downloads: entity.downloads,
      isKidFriendly: entity.isKidFriendly,
      processed: entity.processed,
      isLikeEnabled: entity.isLikeEnabled,
      showLikeCount: entity.showLikeCount,
      isDislikeEnabled: entity.isDislikeEnabled,
      showDislikeCount: entity.showDislikeCount,
      isCommentsEnabled: entity.isCommentsEnabled,
    );
  }
}
