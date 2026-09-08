import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/utils/timestamp_utils.dart';

enum PlaylistVisibility { public, private, unlisted }

class PlaylistItem {
  // For manual ordering

  PlaylistItem({
    required this.videoId,
    required this.title,
    required this.thumbnailUrl,
    required this.addedAt,
    this.position = 0,
  });

  factory PlaylistItem.fromMap(Map<String, dynamic> map) => PlaylistItem(
    videoId: map['videoId'] ?? '',
    title: map['title'] ?? '',
    thumbnailUrl: map['thumbnailUrl'] ?? '',
    addedAt: TimestampUtils.parse(map['addedAt']),
    position: map['position'] ?? 0,
  );
  final String videoId;
  final String title;
  final String thumbnailUrl;
  final Timestamp addedAt;
  final int position;

  Map<String, dynamic> toMap() => {
    'videoId': videoId,
    'title': title,
    'thumbnailUrl': thumbnailUrl,
    'addedAt': addedAt,
    'position': position,
  };
}

class PlaylistModel {
  PlaylistModel({
    required this.id,
    required this.ownerId,
    required this.channelId,
    String? name,
    String? playlistName,
    this.description = '',
    this.thumbnailUrl = '',
    this.videoCount = 0,
    PlaylistVisibility? visibility,
    bool? isPublic,
    this.videoIds = const [],
    dynamic createdAt, // Accept Timestamp or DateTime
    dynamic updatedAt, // Accept Timestamp or DateTime
    this.sortIndex = 0,
    this.geminiApproved,
    this.status = 'underReview',
    this.moderationReason,
  }) : name = name ?? playlistName ?? '',
       visibility =
           visibility ??
           (isPublic ?? false
               ? PlaylistVisibility.public
               : PlaylistVisibility.private),
       createdAt = TimestampUtils.parse(createdAt),
       updatedAt = TimestampUtils.parse(updatedAt);

  factory PlaylistModel.fromMap(Map<String, dynamic> data, String docId) {
    var rawName = (data['name'] as String?)?.trim() ?? (data['playlistName'] as String?)?.trim() ?? (data['title'] as String?)?.trim() ?? '';
    if (rawName.isEmpty || rawName.toLowerCase().startsWith('untitled')) {
      rawName = 'Truthworld Playlist';
    }

    return PlaylistModel(
      id: docId,
      name: rawName,
      description: data['description'] ?? '',
      ownerId: data['ownerId'] ?? data['userId'] ?? '',
      channelId: data['channelId'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      videoCount: (data['videoCount'] as num?)?.toInt() ?? (data['videoIds'] as List?)?.length ?? 0,
      videoIds: List<String>.from(data['videoIds'] ?? []),
      visibility: PlaylistVisibility.values.firstWhere(
        (e) => e.name == data['visibility'],
        orElse: () => data['isPublic'] == true
            ? PlaylistVisibility.public
            : PlaylistVisibility.private,
      ),
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
      sortIndex: data['sortIndex'] ?? 0,
      geminiApproved: data['geminiApproved'],
      status: data['status'] ?? 'active',
      moderationReason: data['moderationReason'],
    );
  }

  factory PlaylistModel.fromDocumentSnapshot(DocumentSnapshot doc) {
    return PlaylistModel.fromMap(doc.data()! as Map<String, dynamic>, doc.id);
  }
  final String id;
  final String name;
  final String description;
  final String ownerId;
  final String channelId;

  // Metadata
  final String thumbnailUrl;
  final int videoCount;
  final PlaylistVisibility visibility;
  final List<String> videoIds; // Backward compatibility
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final int sortIndex; // For manual ordering/indexing

  // Moderation fields
  final bool? geminiApproved;
  final String status;
  final String? moderationReason;

  // Compatibility Getters
  String get playlistName => name;
  bool get isPublic => visibility == PlaylistVisibility.public;

  /// Check if the playlist has valid metadata and at least 1 video to be displayed in discovery feeds
  bool get isValidPlaylist {
    final t = name.trim().toLowerCase();
    if (t.isEmpty ||
        t == 'playlist' ||
        t == 'truthworld playlist' ||
        t == 'untitled' ||
        t == 'untitled playlist' ||
        t.startsWith('untitled')) {
      return false;
    }
    if (status.trim().toLowerCase() != 'active' &&
        status.trim().toLowerCase() != 'ready' &&
        status.trim().toLowerCase() != 'processed') {
      return false;
    }
    if (videoCount <= 0 && videoIds.isEmpty) {
      return false;
    }
    return true;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'playlistName': name, // Store both for backward compatibility
      'description': description,
      'ownerId': ownerId,
      'channelId': channelId,
      'thumbnailUrl': thumbnailUrl,
      'videoCount': videoCount,
      'videoIds': videoIds,
      'visibility': visibility.name,
      'isPublic': isPublic,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'sortIndex': sortIndex,
      'geminiApproved': geminiApproved,
      'status': status,
      'moderationReason': moderationReason,
    };
  }
}
