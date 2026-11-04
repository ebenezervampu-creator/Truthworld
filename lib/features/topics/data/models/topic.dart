import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/utils/timestamp_utils.dart';
import 'package:truthworld/domain/entities/topic_entity.dart';

enum TopicVisibilityType {
  public,
  channelOnly,
  private;

  String toJson() => name;
  static TopicVisibilityType fromJson(String name) =>
      values.firstWhere((v) => v.name == name, orElse: () => public);
}

/// Topic model representing a knowledge hub for related videos
///
/// Stored in Firestore at: topics/{topicId}
class Topic {
  const Topic({
    required this.id,
    required this.slug,
    required this.handle,
    required this.handleLowercase,
    required this.description,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
    String? name,
    String? title,
    this.thumbnailUrl,
    this.coverImage,
    this.videoCount = 0,
    this.postCount = 0,
    this.channelCount = 0,
    this.featuredVideoIds = const [],
    this.relatedTopics = const [],
    this.tags = const [],
    this.likeCount = 0,
    this.commentCount = 0,
    this.views = 0,
    this.trendingScore = 0.0,
    this.channelId,
    this.creatorId,
    this.visibilityType = TopicVisibilityType.public,
    this.accessCode,
    this.followerCount = 0,
    this.status = 'active',
    this.geminiApproved,
    this.moderationReason,
  }) : name = (name != null && name != '')
            ? name
            : ((title != null && title != '') ? title : '');

  /// Create from Firestore document
  factory Topic.fromDocumentSnapshot(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final slugVal = (data['slug'] as String?)?.trim() ?? '';
    var rawName = (data['name'] as String?)?.trim() ??
        (data['title'] as String?)?.trim() ??
        '';
    if (rawName.isEmpty || rawName.toLowerCase().startsWith('untitled')) {
      rawName = slugVal.isNotEmpty ? slugVal.replaceAll('-', ' ') : '';
    }

    final rawHandle = (data['handle'] as String?)?.trim() ?? '';
    final handleVal = rawHandle.isNotEmpty
        ? rawHandle
        : (slugVal.isNotEmpty ? 'T/$slugVal' : '');
    final rawHandleLower = (data['handleLowercase'] as String?)?.trim() ?? '';
    final handleLowerVal = rawHandleLower.isNotEmpty
        ? rawHandleLower
        : (slugVal.isNotEmpty ? 't/${slugVal.toLowerCase()}' : '');

    return Topic(
      id: doc.id,
      name: rawName,
      title: rawName,
      slug: slugVal,
      handle: handleVal,
      handleLowercase: handleLowerVal,
      description: (data['description'] as String?) ?? '',
      category: (data['category'] as String?) ?? '',
      thumbnailUrl: data['thumbnailUrl'] as String?,
      coverImage: data['coverImage'] as String?,
      videoCount: (data['videoCount'] as num?)?.toInt() ?? 0,
      postCount: (data['postCount'] as num?)?.toInt() ?? 0,
      channelCount: (data['channelCount'] as num?)?.toInt() ??
          (data['channels'] is List
              ? (data['channels'] as List).length
              : (data['channelId'] != null &&
                      (data['channelId'] as String).isNotEmpty
                  ? 1
                  : 0)),
      featuredVideoIds: List<String>.from(data['featuredVideoIds'] ?? []),
      relatedTopics: List<String>.from(data['relatedTopics'] ?? []),
      tags: List<String>.from(data['tags'] ?? []).take(5).toList(),
      createdAt:
          TimestampUtils.parseToDateTime(data['createdAt']) ?? DateTime.now(),
      updatedAt:
          TimestampUtils.parseToDateTime(data['updatedAt']) ?? DateTime.now(),
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      views: (data['views'] as num?)?.toInt() ?? 0,
      trendingScore: (data['trendingScore'] as num?)?.toDouble() ?? 0.0,
      channelId: data['channelId'] as String?,
      creatorId: data['creatorId'] as String?,
      visibilityType: TopicVisibilityType.fromJson(
        data['visibilityType'] as String? ?? 'public',
      ),
      accessCode: data['accessCode'] as String?,
      followerCount: (data['followerCount'] as num?)?.toInt() ??
          (data['followers'] as num?)?.toInt() ??
          (data['followersCount'] as num?)?.toInt() ??
          0,
      status: (data['status'] as String?) ?? 'active',
      geminiApproved: data['geminiApproved'] as bool?,
      moderationReason: data['moderationReason'] as String?,
    );
  }

  /// Create from Map (e.g. from local storage cache)
  factory Topic.fromMap(Map<String, dynamic> map, {String? docId}) {
    final slugVal = (map['slug'] as String?)?.trim() ?? '';
    var rawName = (map['name'] as String?)?.trim() ??
        (map['title'] as String?)?.trim() ??
        '';
    if (rawName.isEmpty || rawName.toLowerCase().startsWith('untitled')) {
      rawName = slugVal.isNotEmpty ? slugVal.replaceAll('-', ' ') : '';
    }

    final rawHandle = (map['handle'] as String?)?.trim() ?? '';
    final handleVal = rawHandle.isNotEmpty
        ? rawHandle
        : (slugVal.isNotEmpty ? 'T/$slugVal' : '');
    final rawHandleLower = (map['handleLowercase'] as String?)?.trim() ?? '';
    final handleLowerVal = rawHandleLower.isNotEmpty
        ? rawHandleLower
        : (slugVal.isNotEmpty ? 't/${slugVal.toLowerCase()}' : '');

    return Topic(
      id: docId ?? map['id'] ?? '',
      name: rawName,
      title: rawName,
      slug: slugVal,
      handle: handleVal,
      handleLowercase: handleLowerVal,
      description: (map['description'] as String?) ?? '',
      category: (map['category'] as String?) ?? '',
      thumbnailUrl: map['thumbnailUrl'] as String?,
      coverImage: map['coverImage'] as String?,
      videoCount: (map['videoCount'] as num?)?.toInt() ?? 0,
      postCount: (map['postCount'] as num?)?.toInt() ?? 0,
      channelCount: (map['channelCount'] as num?)?.toInt() ??
          (map['channels'] is List
              ? (map['channels'] as List).length
              : (map['channelId'] != null &&
                      (map['channelId'] as String).isNotEmpty
                  ? 1
                  : 0)),
      featuredVideoIds: List<String>.from(map['featuredVideoIds'] ?? []),
      relatedTopics: List<String>.from(map['relatedTopics'] ?? []),
      tags: List<String>.from(map['tags'] ?? []).take(5).toList(),
      createdAt:
          TimestampUtils.parseToDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt:
          TimestampUtils.parseToDateTime(map['updatedAt']) ?? DateTime.now(),
      likeCount: (map['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (map['commentCount'] as num?)?.toInt() ?? 0,
      views: (map['views'] as num?)?.toInt() ?? 0,
      trendingScore: (map['trendingScore'] as num?)?.toDouble() ?? 0.0,
      channelId: map['channelId'] as String?,
      creatorId: map['creatorId'] as String?,
      visibilityType: TopicVisibilityType.fromJson(
        map['visibilityType'] as String? ?? 'public',
      ),
      accessCode: map['accessCode'] as String?,
      followerCount: (map['followerCount'] as num?)?.toInt() ??
          (map['followers'] as num?)?.toInt() ??
          (map['followersCount'] as num?)?.toInt() ??
          0,
      status: (map['status'] as String?) ?? 'active',
      geminiApproved: map['geminiApproved'] as bool?,
      moderationReason: map['moderationReason'] as String?,
    );
  }
  final String id;
  final String name;
  String get title => name;
  final String slug;
  final String handle;
  final String handleLowercase;
  final String description;
  final String category;
  final String? thumbnailUrl;
  final String? coverImage;
  final int videoCount;
  final int postCount;
  final int channelCount;
  final List<String> featuredVideoIds;
  final List<String> relatedTopics;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int likeCount;
  final int commentCount;
  final int views;
  final double trendingScore;
  final String? channelId;
  final String? creatorId;
  final TopicVisibilityType visibilityType;
  final String? accessCode;
  final int followerCount;
  final String status;
  final bool? geminiApproved;
  final String? moderationReason;

  /// Convert to a map suitable for JSON serialization / caching
  Map<String, dynamic> toCacheMap() {
    return {
      'id': id,
      'name': name,
      'title': name,
      'slug': slug,
      'handle': handle,
      'handleLowercase': handleLowercase,
      'description': description,
      'category': category,
      'thumbnailUrl': thumbnailUrl,
      'coverImage': coverImage,
      'videoCount': videoCount,
      'postCount': postCount,
      'channelCount': channelCount,
      'featuredVideoIds': featuredVideoIds,
      'relatedTopics': relatedTopics,
      'tags': tags.take(5).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'likeCount': likeCount,
      'commentCount': commentCount,
      'views': views,
      'trendingScore': trendingScore,
      'channelId': channelId,
      'creatorId': creatorId,
      'visibilityType': visibilityType.toJson(),
      'accessCode': accessCode,
      'followerCount': followerCount,
      'status': status,
      'geminiApproved': geminiApproved,
      'moderationReason': moderationReason,
    };
  }

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'title': name,
      'slug': slug,
      'handle': handle,
      'handleLowercase': handleLowercase,
      'description': description,
      'category': category,
      'thumbnailUrl': thumbnailUrl,
      'coverImage': coverImage,
      'videoCount': videoCount,
      'postCount': postCount,
      'channelCount': channelCount,
      'featuredVideoIds': featuredVideoIds,
      'relatedTopics': relatedTopics,
      'tags': tags.take(5).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'likeCount': likeCount,
      'commentCount': commentCount,
      'views': views,
      'trendingScore': trendingScore,
      'channelId': channelId,
      'creatorId': creatorId,
      'visibilityType': visibilityType.toJson(),
      'accessCode': accessCode,
      'followerCount': followerCount,
      'status': status,
      'geminiApproved': geminiApproved ?? false,
      'moderationReason': moderationReason,
    };
  }

  /// Create a copy with updated fields
  Topic copyWith({
    String? id,
    String? name,
    String? title,
    String? slug,
    String? handle,
    String? handleLowercase,
    String? description,
    String? category,
    String? thumbnailUrl,
    String? coverImage,
    int? videoCount,
    int? postCount,
    int? channelCount,
    List<String>? featuredVideoIds,
    List<String>? relatedTopics,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? likeCount,
    int? commentCount,
    int? views,
    double? trendingScore,
    String? channelId,
    String? creatorId,
    TopicVisibilityType? visibilityType,
    String? accessCode,
    int? followerCount,
    String? status,
    bool? geminiApproved,
    String? moderationReason,
  }) {
    final updatedName = name ?? title ?? this.name;
    return Topic(
      id: id ?? this.id,
      name: updatedName,
      title: updatedName,
      slug: slug ?? this.slug,
      handle: handle ?? this.handle,
      handleLowercase: handleLowercase ?? this.handleLowercase,
      description: description ?? this.description,
      category: category ?? this.category,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      coverImage: coverImage ?? this.coverImage,
      videoCount: videoCount ?? this.videoCount,
      postCount: postCount ?? this.postCount,
      channelCount: channelCount ?? this.channelCount,
      featuredVideoIds: featuredVideoIds ?? this.featuredVideoIds,
      relatedTopics: relatedTopics ?? this.relatedTopics,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      views: views ?? this.views,
      trendingScore: trendingScore ?? this.trendingScore,
      channelId: channelId ?? this.channelId,
      creatorId: creatorId ?? this.creatorId,
      visibilityType: visibilityType ?? this.visibilityType,
      accessCode: accessCode ?? this.accessCode,
      followerCount: followerCount ?? this.followerCount,
      status: status ?? this.status,
      geminiApproved: geminiApproved ?? this.geminiApproved,
      moderationReason: moderationReason ?? this.moderationReason,
    );
  }

  /// Computed video count giving priority to videoCount counter and falling back to featuredVideoIds length.
  int get effectiveVideoCount =>
      videoCount > 0 ? videoCount : featuredVideoIds.length;

  /// Canonical identifier for topic deduplication across documents.
  /// Strips any auto-generated UUID suffixes (e.g. "worship-music-a1b2c3" -> "worship-music")
  /// and normalizes to lowercase.
  String get canonicalKey {
    var s = slug.trim().toLowerCase();
    final uuidPattern = RegExp(r'-[a-f0-9]{6,8}$');
    s = s.replaceAll(uuidPattern, '');
    if (s.isNotEmpty) return s;
    final n = name.trim().toLowerCase();
    if (n.isNotEmpty) return n;
    return id.toLowerCase();
  }

  /// Whether the topic is archived, deleted, or in trash
  bool get isArchivedOrDeleted {
    final lowerStatus = status.trim().toLowerCase();
    return lowerStatus == 'deleted' ||
        lowerStatus == 'archived' ||
        lowerStatus == 'trash' ||
        lowerStatus == 'empty_archived' ||
        lowerStatus == 'deletion_pending';
  }

  /// Check if the topic has valid content and metadata to be displayed in feeds/discovery.
  bool get isValidTopic {
    if (slug.trim().isEmpty) return false;
    if (name.trim().isEmpty) return false;
    final lowerName = name.trim().toLowerCase();
    final lowerSlug = slug.trim().toLowerCase();
    if (lowerName == 'featured topic' ||
        lowerName == 'topic' ||
        lowerName.startsWith('untitled') ||
        lowerSlug == 'topic' ||
        lowerSlug == 'featured-topic' ||
        lowerSlug.startsWith('untitled')) {
      return false;
    }
    if (isArchivedOrDeleted) {
      return false;
    }
    final lowerStatus = status.trim().toLowerCase();
    if (lowerStatus == 'verificationrejected') {
      return false;
    }
    if (lowerStatus == 'rejected') {
      // If falsely rejected due to asynchronous zero-video race condition or AI moderation timeout but has linked videos, allow recovery
      final reason = moderationReason?.toLowerCase().trim() ?? '';
      final isZeroVideoRace = reason.isNotEmpty &&
          (reason.contains('video') ||
              reason.contains('at least 1') ||
              reason.contains('0 video') ||
              reason.contains('moderation check failed') ||
              reason.contains('timeout') ||
              reason.contains('invalid response format'));
      if (isZeroVideoRace &&
          (featuredVideoIds.isNotEmpty || effectiveVideoCount > 0)) {
        return true;
      }
      return false;
    }
    if (effectiveVideoCount <= 0 && postCount <= 0) return false;
    return true;
  }

  /// Returns the routing parameter (the handle without "T/" prefix, or slug as fallback)
  String get routePathParameter {
    var raw = handle.trim();
    while (raw.startsWith('/')) {
      raw = raw.substring(1).trim();
    }
    while (raw.startsWith('@')) {
      raw = raw.substring(1).trim();
    }
    if (raw.toLowerCase().startsWith('t/')) {
      raw = raw.substring(2).trim();
    }
    while (raw.startsWith('/')) {
      raw = raw.substring(1).trim();
    }
    if (raw.isNotEmpty && raw.toLowerCase() != 't') {
      return raw;
    }
    var s = slug.trim();
    while (s.startsWith('/')) {
      s = s.substring(1).trim();
    }
    return s;
  }

  String get topicRoute {
    final param = routePathParameter;
    if (param.isEmpty) {
      return '/explore-topics';
    }
    return '/T/$param';
  }

  /// Converts this data model to a pure domain [TopicEntity].
  TopicEntity toEntity() {
    return TopicEntity(
      id: id,
      name: name,
      title: name,
      slug: slug,
      handle: handle,
      description: description,
      category: category,
      createdAt: createdAt,
      updatedAt: updatedAt,
      thumbnailUrl: thumbnailUrl,
      coverImage: coverImage,
      videoCount: videoCount,
      postCount: postCount,
      followerCount: followerCount,
      channelCount: channelCount,
      views: views,
      likeCount: likeCount,
      commentCount: commentCount,
      trendingScore: trendingScore,
      status: status,
      channelId: channelId,
      creatorId: creatorId,
      tags: tags,
      featuredVideoIds: featuredVideoIds,
      relatedTopics: relatedTopics,
    );
  }

  /// Creates a [Topic] data model from a pure domain [TopicEntity].
  static Topic fromEntity(TopicEntity entity) {
    return Topic(
      id: entity.id,
      name: entity.name,
      title: entity.title,
      slug: entity.slug,
      handle: entity.handle,
      handleLowercase: entity.handle.toLowerCase(),
      description: entity.description,
      category: entity.category,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      thumbnailUrl: entity.thumbnailUrl,
      coverImage: entity.coverImage,
      videoCount: entity.videoCount,
      postCount: entity.postCount,
      followerCount: entity.followerCount,
      channelCount: entity.channelCount,
      views: entity.views,
      likeCount: entity.likeCount,
      commentCount: entity.commentCount,
      trendingScore: entity.trendingScore,
      status: entity.status,
      channelId: entity.channelId,
      creatorId: entity.creatorId,
      tags: entity.tags,
      featuredVideoIds: entity.featuredVideoIds,
      relatedTopics: entity.relatedTopics,
    );
  }
}

/// Lightweight topic reference for related topics list
class TopicRef {
  const TopicRef({
    required this.id,
    required this.slug,
    String? name,
    String? title,
    this.thumbnailUrl,
    this.videoCount = 0,
  }) : name = (name != null && name != '')
            ? name
            : ((title != null && title != '') ? title : '');

  factory TopicRef.fromMap(Map<String, dynamic> map) {
    final rawName = (map['name'] as String?)?.trim() ??
        (map['title'] as String?)?.trim() ??
        '';
    return TopicRef(
      id: map['id'] ?? '',
      name: rawName,
      title: rawName,
      slug: map['slug'] ?? '',
      thumbnailUrl: map['thumbnailUrl'],
      videoCount: map['videoCount'] ?? 0,
    );
  }
  final String id;
  final String name;
  String get title => name;
  final String slug;
  final String? thumbnailUrl;
  final int videoCount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'title': name,
      'slug': slug,
      'thumbnailUrl': thumbnailUrl,
      'videoCount': videoCount,
    };
  }
}
