import 'package:truthworld/data/models/offline.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Serializer converting [Video] instances to Firestore-compatible maps and offline models.
class VideoSerializer {
  const VideoSerializer._();

  /// Converts a [Video] to a Firestore-compatible JSON map.
  static Map<String, dynamic> toMap(Video video) {
    return {
      'id': video.id,
      'title': video.title,
      'titleLowercase': video.titleLowercase,
      'description': video.description,
      'originalUrl': video.originalUrl,
      'hlsUrl': video.hlsUrl,
      'dashUrl': video.dashUrl,
      'storyboardUrl': video.storyboardUrl,
      'storyboardVariants': video.storyboardVariants,
      'adaptiveResolutions':
          video.adaptiveResolutions.map((e) => e.toMap()).toList(),
      'thumbnailUrl': video.thumbnailUrl,
      'thumbnailVariants': video.thumbnailVariants,
      'animatedPreviewUrl': video.animatedPreviewUrl,
      'ownerId': video.ownerId,
      'channelId': video.channelId,
      'channelName': video.channelName,
      'channelAvatarUrl': video.channelAvatarUrl,
      'viewCount': video.viewCount,
      'views': video.viewCount,
      'likeCount': video.likeCount,
      'dislikeCount': video.dislikeCount,
      'commentCount': video.commentCount,
      'shareCount': video.shareCount,
      'durationMs': video.durationValue.inMilliseconds,
      'createdAt': video.createdAt.millisecondsSinceEpoch,
      'uploadedAt': video.createdAt.millisecondsSinceEpoch,
      'updatedAt': video.updatedAt.millisecondsSinceEpoch,
      'status': video.status.name,
      'visibility': video.visibility,
      'category': video.category,
      'tags': video.tags,
      'topics': video.topics,
      'language': video.language,
      'languages': video.languages,
      'isShort': video.isShort,
      'isKidFriendly': video.isKidFriendly,
      'enableComments': video.enableComments,
      'allowClipping': video.allowClipping,
      'isMonetized': video.isMonetized,
      'allowRatings': video.allowRatings,
      'showLikeCount': video.showLikeCount,
      'showDislikeCount': video.showDislikeCount,
      'autoChaptersEnabled': video.autoChaptersEnabled,
      'trustScore': video.trustScore,
      'sourceLinks': video.sourceLinks,
      'isFactChecked': video.isFactChecked,
      'factCheckTier': video.factCheckTier,
      'factCheckReviewMode': video.factCheckReviewMode,
      'isFactCheckApproved': video.isFactCheckApproved,
      'isVerified': video.isVerified,
      'qualifiedViewCount': video.viewCount,
      'totalWatchTimeSeconds': video.totalWatchTimeSeconds,
      'likedBy': video.likedBy,
      'trustLabel': video.trustLabel,
      'channelStatus': video.channelStatus,
      'scheduledPublishAt':
          video.scheduledPublishAt?.millisecondsSinceEpoch,
      'coinBattlePairVideoId': video.coinBattlePairVideoId,
      'coinBattleStance': video.coinBattleStance,
      'moderationSummary': video.moderationSummary,
      'resubmitCount': video.resubmitCount,
      if (video.embedding != null) 'embedding': video.embedding,
    };
  }

  /// Converts a [Video] to an [OfflineVideo] record for offline viewing.
  static OfflineVideo toOffline(Video video) {
    return OfflineVideo(
      id: video.id,
      title: video.title,
      channelName: video.channelName,
      channelImage: video.channelAvatarUrl,
      views: video.views.toString(),
      thumbnailUrl: video.thumbnailUrl,
      downloadedAt: DateTime.now(),
    );
  }
}
