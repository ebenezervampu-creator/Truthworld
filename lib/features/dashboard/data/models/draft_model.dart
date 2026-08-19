import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a draft item (video or community post) in Creator Studio.
class DraftModel {
  DraftModel({
    required this.id,
    required this.title,
    required this.type,
    this.content = '',
    this.mediaUrl,
    DateTime? updatedAt,
    this.status = 'draft',
    this.userId = '',
    this.channelId = '',
  }) : updatedAt = updatedAt ?? DateTime.now();

  /// Create instance from Map (Firestore document or JSON map)
  factory DraftModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    final rawUpdatedAt = map['updatedAt'];
    DateTime parsedDate;

    if (rawUpdatedAt is Timestamp) {
      parsedDate = rawUpdatedAt.toDate();
    } else if (rawUpdatedAt is String) {
      parsedDate = DateTime.tryParse(rawUpdatedAt) ?? DateTime.now();
    } else if (rawUpdatedAt is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(rawUpdatedAt);
    } else if (rawUpdatedAt is DateTime) {
      parsedDate = rawUpdatedAt;
    } else {
      parsedDate = DateTime.now();
    }

    return DraftModel(
      id: docId ?? map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      type: map['type']?.toString() ?? 'video',
      content:
          map['content']?.toString() ?? map['description']?.toString() ?? '',
      mediaUrl: map['mediaUrl']?.toString() ?? map['thumbnailUrl']?.toString(),
      updatedAt: parsedDate,
      status: map['status']?.toString() ?? 'draft',
      userId: map['userId']?.toString() ?? map['ownerId']?.toString() ?? '',
      channelId: map['channelId']?.toString() ?? '',
    );
  }

  /// Create instance from JSON Map
  factory DraftModel.fromJson(Map<String, dynamic> json) =>
      DraftModel.fromMap(json);

  final String id;
  final String title;
  final String type; // 'video' | 'communityPost'
  final String content;
  final String? mediaUrl;
  final DateTime updatedAt;
  final String status;
  final String userId;
  final String channelId;

  /// Alias getter for description
  String get description => content;

  /// Convert to Map for Firestore or local storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'content': content,
      'description': content,
      'mediaUrl': mediaUrl,
      'updatedAt': updatedAt.toIso8601String(),
      'status': status,
      'userId': userId,
      'channelId': channelId,
    };
  }

  /// Convert to JSON Map
  Map<String, dynamic> toJson() => toMap();

  /// Create copy with updated fields
  DraftModel copyWith({
    String? id,
    String? title,
    String? type,
    String? content,
    String? mediaUrl,
    DateTime? updatedAt,
    String? status,
    String? userId,
    String? channelId,
  }) {
    return DraftModel(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      userId: userId ?? this.userId,
      channelId: channelId ?? this.channelId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DraftModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          type == other.type &&
          content == other.content &&
          mediaUrl == other.mediaUrl &&
          updatedAt == other.updatedAt &&
          status == other.status;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      type.hashCode ^
      content.hashCode ^
      mediaUrl.hashCode ^
      updatedAt.hashCode ^
      status.hashCode;

  @override
  String toString() {
    return 'DraftModel(id: $id, title: $title, type: $type, status: $status, updatedAt: $updatedAt)';
  }
}
