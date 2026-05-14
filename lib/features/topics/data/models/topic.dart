import 'package:cloud_firestore/cloud_firestore.dart';

/// Topic model representing a knowledge hub for related videos
///
/// Stored in Firestore at: topics/{topicId}
class Topic {
  final String id;
  final String title;
  final String slug;
  final String description;
  final String category;
  final String? thumbnailUrl;
  final String? coverImage;
  final int videoCount;
  final List<String> featuredVideoIds;
  final List<String> relatedTopics;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Topic({
    required this.id,
    required this.title,
    required this.slug,
    required this.description,
    required this.category,
    this.thumbnailUrl,
    this.coverImage,
    this.videoCount = 0,
    this.featuredVideoIds = const [],
    this.relatedTopics = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from Firestore document
  factory Topic.fromDocumentSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Topic(
      id: doc.id,
      title: data['title'] ?? '',
      slug: data['slug'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      thumbnailUrl: data['thumbnailUrl'],
      coverImage: data['coverImage'],
      videoCount: data['videoCount'] ?? 0,
      featuredVideoIds: List<String>.from(data['featuredVideoIds'] ?? []),
      relatedTopics: List<String>.from(data['relatedTopics'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'slug': slug,
      'description': description,
      'category': category,
      'thumbnailUrl': thumbnailUrl,
      'coverImage': coverImage,
      'videoCount': videoCount,
      'featuredVideoIds': featuredVideoIds,
      'relatedTopics': relatedTopics,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create a copy with updated fields
  Topic copyWith({
    String? id,
    String? title,
    String? slug,
    String? description,
    String? category,
    String? thumbnailUrl,
    String? coverImage,
    int? videoCount,
    List<String>? featuredVideoIds,
    List<String>? relatedTopics,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Topic(
      id: id ?? this.id,
      title: title ?? this.title,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      category: category ?? this.category,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      coverImage: coverImage ?? this.coverImage,
      videoCount: videoCount ?? this.videoCount,
      featuredVideoIds: featuredVideoIds ?? this.featuredVideoIds,
      relatedTopics: relatedTopics ?? this.relatedTopics,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
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




