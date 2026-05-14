import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/features/commnuity/data/models/poll_model.dart';
import 'package:truthworld/features/commnuity/data/models/quiz_model.dart';

/// Represents a draft community post or quiz
class CommunityDraft {
  final String id; // Draft unique identifier
  final String ownerId; // User ID
  final String channelId; // Selected channel
  final String type; // 'post' or 'quiz'
  final String title;
  final String description; // Used for posts
  final List<String> tags;
  final String category;
  final String visibility; // Public, Unlisted, Private
  final bool isKidFriendly;

  // File URLs in Firebase Storage (temp URLs for drafts)
  final List<String> imageUrls;
  final List<String> imageStoragePaths; // Paths for cleanup
  final String? scheduledPublishDate; // ISO 8601 format

  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;

  // Poll (if type == 'post' and has poll)
  final PollModel? poll;

  // Quiz (if type == 'quiz')
  final QuizModel? quiz;

  CommunityDraft({
    required this.id,
    required this.ownerId,
    required this.channelId,
    required this.type,
    required this.title,
    this.description = '',
    this.tags = const [],
    required this.category,
    required this.visibility,
    this.isKidFriendly = false,
    this.imageUrls = const [],
    this.imageStoragePaths = const [],
    this.scheduledPublishDate,
    required this.createdAt,
    required this.updatedAt,
    this.poll,
    this.quiz,
  });

  /// Convert to Firestore-compatible Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'channelId': channelId,
      'type': type,
      'title': title,
      'description': description,
      'tags': tags,
      'category': category,
      'visibility': visibility,
      'isKidFriendly': isKidFriendly,
      'imageUrls': imageUrls,
      'imageStoragePaths': imageStoragePaths,
      'scheduledPublishDate': scheduledPublishDate,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (poll != null) 'poll': poll!.toMap(),
      if (quiz != null) 'quiz': quiz!.toMap(),
    };
  }

  /// Create instance from Firestore document
  factory CommunityDraft.fromMap(Map<String, dynamic> map, String draftId) {
    return CommunityDraft(
      id: draftId,
      ownerId: map['ownerId'] ?? '',
      channelId: map['channelId'] ?? '',
      type: map['type'] ?? 'post',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      tags: List<String>.from(map['tags'] ?? []),
      category: map['category'] ?? 'General',
      visibility: map['visibility'] ?? 'Private',
      isKidFriendly: map['isKidFriendly'] ?? false,
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      imageStoragePaths: List<String>.from(map['imageStoragePaths'] ?? []),
      scheduledPublishDate: map['scheduledPublishDate'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      poll: map['poll'] != null ? PollModel.fromMap(map['poll']) : null,
      quiz: map['quiz'] != null ? QuizModel.fromMap(map['quiz']) : null,
    );
  }

  /// Create a copy with modifications
  CommunityDraft copyWith({
    String? id,
    String? ownerId,
    String? channelId,
    String? type,
    String? title,
    String? description,
    List<String>? tags,
    String? category,
    String? visibility,
    bool? isKidFriendly,
    List<String>? imageUrls,
    List<String>? imageStoragePaths,
    String? scheduledPublishDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    PollModel? poll,
    QuizModel? quiz,
  }) {
    return CommunityDraft(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      channelId: channelId ?? this.channelId,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      category: category ?? this.category,
      visibility: visibility ?? this.visibility,
      isKidFriendly: isKidFriendly ?? this.isKidFriendly,
      imageUrls: imageUrls ?? this.imageUrls,
      imageStoragePaths: imageStoragePaths ?? this.imageStoragePaths,
      scheduledPublishDate: scheduledPublishDate ?? this.scheduledPublishDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      poll: poll ?? this.poll,
      quiz: quiz ?? this.quiz,
    );
  }

  @override
  String toString() => 'CommunityDraft(id: $id, type: $type, title: $title)';
}





