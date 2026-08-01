import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/base/base_repository.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/domain/entities/channel_entity.dart';
import 'package:truthworld/domain/entities/video_entity.dart';
import 'package:truthworld/domain/repositories/search_repository.dart';
import 'package:truthworld/features/video/data/models/video.dart';

class SearchRepositoryImpl extends BaseRepository implements SearchRepository {
  final FirebaseFirestore _firestore;

  SearchRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  VideoEntity _mapVideoToEntity(Video model) {
    return VideoEntity(
      id: model.id,
      title: model.title,
      description: model.description,
      ownerId: model.ownerId,
      channelId: model.channelId,
      channelName: model.channelName,
      channelAvatarUrl: model.channelAvatarUrl,
      thumbnailUrl: model.thumbnailUrl,
      originalUrl: model.originalUrl,
      hlsUrl: model.hlsUrl,
      dashUrl: model.dashUrl,
      viewCount: model.viewCount,
      likeCount: model.likeCount,
      dislikeCount: model.dislikeCount,
      commentCount: model.commentCount,
      shareCount: model.shareCount,
      duration: model.durationValue,
      createdAt: model.createdAt.toDate(),
      updatedAt: model.updatedAt.toDate(),
      status: model.status.name,
      visibility: model.visibility,
      category: model.category,
      tags: model.tags,
      topics: model.topics,
      language: model.language,
      isShort: model.isShort,
      isKidFriendly: model.isKidFriendly,
      enableComments: model.enableComments,
      isMonetized: model.isMonetized,
      trustScore: model.trustScore,
    );
  }

  ChannelEntity _mapChannelToEntity(Channel model) {
    return ChannelEntity(
      id: model.id,
      name: model.name,
      handle: model.handle,
      ownerId: model.ownerId,
      createdAt: model.createdAt.toDate(),
      updatedAt: model.updatedAt.toDate(),
      description: model.description,
      avatarUrl: model.avatarUrl,
      bannerUrl: model.bannerUrl,
      subscriberCount: model.subscriberCount,
      videoCount: model.videoCount,
      totalViews: model.viewCount,
      isVerified: model.isVerified,
      status: model.status.name,
      category: model.category,
      categories: model.categories,
    );
  }

  @override
  Future<Result<List<VideoEntity>>> searchVideos(
    String query, {
    int limit = 20,
    dynamic cursor,
  }) async {
    return safeFetch(() async {
      final queryLower = query.toLowerCase();
      var q = _firestore
          .collection(FirestoreCollections.videos)
          .where('titleLowercase', isGreaterThanOrEqualTo: queryLower)
          .where('titleLowercase', isLessThanOrEqualTo: '$queryLower\uf8ff')
          .where('visibility', isEqualTo: 'public')
          .limit(limit);

      if (cursor != null && cursor is DocumentSnapshot) {
        q = q.startAfterDocument(cursor);
      }

      final snapshot = await q.get();
      return snapshot.docs
          .map((doc) => _mapVideoToEntity(Video.fromDocumentSnapshot(doc)))
          .toList();
    });
  }

  @override
  Future<Result<List<ChannelEntity>>> searchChannels(
    String query, {
    int limit = 20,
    dynamic cursor,
  }) async {
    return safeFetch(() async {
      final queryLower = query.toLowerCase();
      var q = _firestore
          .collection(FirestoreCollections.channels)
          .where('nameLowercase', isGreaterThanOrEqualTo: queryLower)
          .where('nameLowercase', isLessThanOrEqualTo: '$queryLower\uf8ff')
          .limit(limit);

      if (cursor != null && cursor is DocumentSnapshot) {
        q = q.startAfterDocument(cursor);
      }

      final snapshot = await q.get();
      return snapshot.docs
          .map((doc) => _mapChannelToEntity(Channel.fromDocumentSnapshot(doc)))
          .toList();
    });
  }
}
