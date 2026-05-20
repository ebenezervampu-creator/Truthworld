import 'package:cloud_firestore/cloud_firestore.dart';

enum PlaylistVisibility { public, private, unlisted }

class PlaylistItem {
  final String videoId;
  final String title;
  final String thumbnailUrl;
  final Timestamp addedAt;
  final int position; // For manual ordering

  PlaylistItem({
    required this.videoId,
    required this.title,
    required this.thumbnailUrl,
    required this.addedAt,
    this.position = 0,
  });

  Map<String, dynamic> toMap() => {
    'videoId': videoId,
    'title': title,
    'thumbnailUrl': thumbnailUrl,
    'addedAt': addedAt,
    'position': position,
  };

  factory PlaylistItem.fromMap(Map<String, dynamic> map) => PlaylistItem(
    videoId: map['videoId'] ?? '',
    title: map['title'] ?? '',
    thumbnailUrl: map['thumbnailUrl'] ?? '',
    addedAt: map['addedAt'] ?? Timestamp.now(),
    position: map['position'] ?? 0,
  );
}

class PlaylistModel {
  final String id;
  final String name;
  final String nameLowercase; // For search efficiency
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

  // Compatibility Getters
  String get playlistName => name;
  bool get isPublic => visibility == PlaylistVisibility.public;

  PlaylistModel({
    required this.id,
    String? name,
    String? playlistName,
    this.description = '',
    required this.ownerId,
    required this.channelId,
    this.thumbnailUrl = '',
    this.videoCount = 0,
    PlaylistVisibility? visibility,
    bool? isPublic,
    this.videoIds = const [],
    dynamic createdAt, // Accept Timestamp or DateTime
    dynamic updatedAt, // Accept Timestamp or DateTime
    this.sortIndex = 0,
  }) : name = name ?? playlistName ?? '',
       nameLowercase = (name ?? playlistName ?? '').toLowerCase(),
       visibility =
           visibility ??
           (isPublic == true
               ? PlaylistVisibility.public
               : PlaylistVisibility.private),
       createdAt = createdAt is Timestamp
           ? createdAt
           : (createdAt is DateTime
                 ? Timestamp.fromDate(createdAt)
                 : Timestamp.now()),
       updatedAt = updatedAt is Timestamp
           ? updatedAt
           : (updatedAt is DateTime
                 ? Timestamp.fromDate(updatedAt)
                 : Timestamp.now());

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'nameLowercase': nameLowercase,
      'playlistName': name, // Store both for backward compatibility
      'description': description,
      'ownerId': ownerId,
      'channelId': channelId,
      'thumbnailUrl': thumbnailUrl,
      'videoCount': videoCount,
      'videoIds': videoIds,
      'visibility': visibility.name,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'sortIndex': sortIndex,
    };
  }

  factory PlaylistModel.fromMap(Map<String, dynamic> data, String docId) {
    return PlaylistModel(
      id: docId,
      name: data['name'] ?? data['playlistName'] ?? '', // Handle both old and new field names
      description: data['description'] ?? '',
      ownerId: data['ownerId'] ?? '',
      channelId: data['channelId'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      videoCount: data['videoCount'] ?? 0,
      videoIds: List<String>.from(data['videoIds'] ?? []),
      visibility: PlaylistVisibility.values.firstWhere(
        (e) => e.name == data['visibility'],
        orElse: () => PlaylistVisibility.private,
      ),
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
      sortIndex: data['sortIndex'] ?? 0,
    );
  }

  factory PlaylistModel.fromDocumentSnapshot(DocumentSnapshot doc) {
    return PlaylistModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }
}





