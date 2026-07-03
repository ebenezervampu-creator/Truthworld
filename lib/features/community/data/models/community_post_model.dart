import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/features/community/data/models/poll_model.dart';

/// Data model for a community post with multi-image and optional poll support.
class CommunityPostModel {
  final String id;
  final String title;
  final String description;
  final String ownerId;
  final String channelId;
  final String channelName;
  final String channelImage;
  final String selectedCategory;
  final String visibility;
  final List<String> images;
  final List<String> tags;
  final PollModel? poll;
  final DateTime uploadedAt;
  final DateTime? scheduledTime;
  final int likes;
  final int views;
  final int downloads;
  final List<String> likedBy;
  final List<String> shares;
  final bool isKidFriendly;
  final bool processed;

  const CommunityPostModel({
    required this.id,
    required this.title,
    required this.description,
    required this.ownerId,
    required this.channelId,
    required this.channelName,
    required this.channelImage,
    this.selectedCategory = 'General',
    this.visibility = 'Public',
    this.images = const [],
    this.tags = const [],
    this.poll,
    required this.uploadedAt,
    this.scheduledTime,
    this.likes = 0,
    this.views = 0,
    this.downloads = 0,
    this.likedBy = const [],
    this.shares = const [],
    this.isKidFriendly = false,
    this.processed = false,
  });

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
    'images': images,
    // Keep backward-compatible 'image' field (first image or empty)
    'image': images.isNotEmpty ? images.first : '',
    'tags': tags,
    if (poll != null) 'poll': poll!.toMap(),
    'uploadedAt': Timestamp.fromDate(uploadedAt),
    if (scheduledTime != null)
      'scheduledTime': Timestamp.fromDate(scheduledTime!),
    'likes': likes,
    'views': views,
    'downloads': downloads,
    'likedby': likedBy,
    'shares': shares,
    'isKidFriendly': isKidFriendly,
    'processed': processed,
  };

  factory CommunityPostModel.fromMap(Map<String, dynamic> map) {
    // Support both 'images' array and legacy single 'image' field
    List<String> imageList = [];
    if (map['images'] != null) {
      imageList = List<String>.from(map['images']);
    } else if (map['image'] != null && (map['image'] as String).isNotEmpty) {
      imageList = [map['image'] as String];
    }

    return CommunityPostModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      ownerId: map['ownerId'] ?? '',
      channelId: map['channelId'] ?? '',
      channelName: map['channelName'] ?? '',
      channelImage: map['channelImage'] ?? '',
      selectedCategory: map['selectedCategory'] ?? 'General',
      visibility: map['visibility'] ?? 'Public',
      images: imageList,
      tags: List<String>.from(map['tags'] ?? []),
      poll: map['poll'] != null
          ? PollModel.fromMap(Map<String, dynamic>.from(map['poll']))
          : null,
      uploadedAt: map['uploadedAt'] != null
          ? (map['uploadedAt'] as Timestamp).toDate()
          : DateTime.now(),
      scheduledTime: map['scheduledTime'] != null
          ? (map['scheduledTime'] as Timestamp).toDate()
          : null,
      likes: map['likes'] ?? 0,
      views: map['views'] ?? 0,
      downloads: map['downloads'] ?? 0,
      likedBy: List<String>.from(map['likedby'] ?? []),
      shares: List<String>.from(map['shares'] ?? []),
      isKidFriendly: map['isKidFriendly'] ?? false,
      processed: map['processed'] ?? false,
    );
  }
}
