import 'package:cloud_firestore/cloud_firestore.dart';

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
  final String id;
  final String title;
  final String slug;
  final String handle;
  final String handleLowercase;
  final String description;
  final String category;
  final String? thumbnailUrl;
  final String? coverImage;
  final int videoCount;
  final List<String> featuredVideoIds;
  final List<String> relatedTopics;
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

  const Topic({
    required this.id,
    required this.title,
    required this.slug,
    required this.handle,
    required this.handleLowercase,
    required this.description,
    required this.category,
    this.thumbnailUrl,
    this.coverImage,
    this.videoCount = 0,
    this.featuredVideoIds = const [],
    this.relatedTopics = const [],
    required this.createdAt,
    required this.updatedAt,
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
  });

  /// Create from Firestore document
  factory Topic.fromDocumentSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final slugVal = data['slug'] ?? '';
    return Topic(
      id: doc.id,
      title: data['title'] ?? '',
      slug: slugVal,
      handle: data['handle'] ?? 'T/$slugVal',
      handleLowercase: data['handleLowercase'] ?? 't/${slugVal.toLowerCase()}',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      thumbnailUrl: data['thumbnailUrl'],
      coverImage: data['coverImage'],
      videoCount: data['videoCount'] ?? 0,
      featuredVideoIds: List<String>.from(data['featuredVideoIds'] ?? []),
      relatedTopics: List<String>.from(data['relatedTopics'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likeCount: data['likeCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      views: data['views'] ?? 0,
      trendingScore: (data['trendingScore'] as num?)?.toDouble() ?? 0.0,
      channelId: data['channelId'],
      creatorId: data['creatorId'],
      visibilityType: TopicVisibilityType.fromJson(data['visibilityType'] ?? 'public'),
      accessCode: data['accessCode'],
      followerCount: data['followerCount'] ?? 0,
      status: data['status'] ?? 'active',
      geminiApproved: data['geminiApproved'] as bool?,
      moderationReason: data['moderationReason'] as String?,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'slug': slug,
      'handle': handle,
      'handleLowercase': handleLowercase,
      'description': description,
      'category': category,
      'thumbnailUrl': thumbnailUrl,
      'coverImage': coverImage,
      'videoCount': videoCount,
      'featuredVideoIds': featuredVideoIds,
      'relatedTopics': relatedTopics,
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
      'geminiApproved': geminiApproved,
      'moderationReason': moderationReason,
    };
  }

  /// Create a copy with updated fields
  Topic copyWith({
    String? id,
    String? title,
    String? slug,
    String? handle,
    String? handleLowercase,
    String? description,
    String? category,
    String? thumbnailUrl,
    String? coverImage,
    int? videoCount,
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
    return Topic(
      id: id ?? this.id,
      title: title ?? this.title,
      slug: slug ?? this.slug,
      handle: handle ?? this.handle,
      handleLowercase: handleLowercase ?? this.handleLowercase,
      description: description ?? this.description,
      category: category ?? this.category,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      coverImage: coverImage ?? this.coverImage,
      videoCount: videoCount ?? this.videoCount,
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

  /// Returns the routing parameter (the handle without "T/" prefix, or slug as fallback)
  String get routePathParameter {
    if (handle.isNotEmpty) {
      String clean = handle.trim();
      if (clean.startsWith('T/')) {
        return clean.substring(2);
      }
      if (clean.startsWith('t/')) {
        return clean.substring(2);
      }
      return clean;
    }
    return slug;
  }

  String get topicRoute => '/T/$routePathParameter';
}

/// Lightweight topic reference for related topics list
class TopicRef {
  final String id;
  final String title;
  final String slug;
  final String? thumbnailUrl;
  final int videoCount;

  const TopicRef({
    required this.id,
    required this.title,
    required this.slug,
    this.thumbnailUrl,
    this.videoCount = 0,
  });

  factory TopicRef.fromMap(Map<String, dynamic> map) {
    return TopicRef(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      slug: map['slug'] ?? '',
      thumbnailUrl: map['thumbnailUrl'],
      videoCount: map['videoCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'slug': slug,
      'thumbnailUrl': thumbnailUrl,
      'videoCount': videoCount,
    };
  }
}




