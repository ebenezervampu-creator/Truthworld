import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/data/models/playlist_model.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/video.dart';

enum ContentType {
  video,
  playlist,
  communityPost,
  topic,
}

class SubscriptionContent {
  SubscriptionContent({
    required this.id,
    required this.type,
    required this.algorithmicScore,
    required this.createdAt,
    this.video,
    this.playlist,
    this.communityPost,
    this.topic,
  });

  factory SubscriptionContent.fromVideo(Video video) {
    final score = _calculateVideoScore(video);
    return SubscriptionContent(
      id: video.id,
      type: ContentType.video,
      video: video,
      algorithmicScore: score,
      createdAt: video.createdAt,
    );
  }

  factory SubscriptionContent.fromPlaylist(PlaylistModel playlist) {
    final score = _calculatePlaylistScore(playlist);
    return SubscriptionContent(
      id: playlist.id,
      type: ContentType.playlist,
      playlist: playlist,
      algorithmicScore: score,
      createdAt: playlist.createdAt,
    );
  }

  factory SubscriptionContent.fromCommunityPost(CommunityPostModel post) {
    final score = _calculateCommunityPostScore(post);
    return SubscriptionContent(
      id: post.id,
      type: ContentType.communityPost,
      communityPost: post,
      algorithmicScore: score,
      createdAt: Timestamp.fromDate(post.uploadedAt),
    );
  }

  factory SubscriptionContent.fromTopic(Topic topic) {
    final score = _calculateTopicScore(topic);
    return SubscriptionContent(
      id: topic.id,
      type: ContentType.topic,
      topic: topic,
      algorithmicScore: score,
      createdAt: Timestamp.fromDate(topic.createdAt),
    );
  }

  final String id;
  final ContentType type;
  final Video? video;
  final PlaylistModel? playlist;
  final CommunityPostModel? communityPost;
  final Topic? topic;
  final double algorithmicScore;
  final Timestamp createdAt;

  static double _calculateVideoScore(Video video) {
    final daysSinceUpload = DateTime.now()
        .difference(video.createdAt.toDate())
        .inDays;
    final recencyFactor = 1.0 / (1 + daysSinceUpload * 0.1);
    final viewsFactor = video.views > 0 ? (video.views / 1000).clamp(0, 10) : 0;
    final likesFactor = video.likes > 0 ? (video.likes / 100).clamp(0, 5) : 0;

    return recencyFactor * 5 + viewsFactor * 3 + likesFactor * 2;
  }

  static double _calculatePlaylistScore(PlaylistModel playlist) {
    final daysSinceUpload = DateTime.now()
        .difference(playlist.createdAt.toDate())
        .inDays;
    final recencyFactor = 1.0 / (1 + daysSinceUpload * 0.1);
    final videoCountFactor = (playlist.videoCount / 10).clamp(0, 5);

    return recencyFactor * 5 + videoCountFactor * 3;
  }

  static double _calculateCommunityPostScore(CommunityPostModel post) {
    final daysSinceUpload = DateTime.now().difference(post.uploadedAt).inDays;
    final recencyFactor = 1.0 / (1 + daysSinceUpload * 0.1);
    final likesFactor = post.likes > 0 ? (post.likes / 50).clamp(0, 5) : 0;
    final viewsFactor = post.views > 0 ? (post.views / 500).clamp(0, 3) : 0;

    return recencyFactor * 5 + likesFactor * 3 + viewsFactor * 2;
  }

  static double _calculateTopicScore(Topic topic) {
    final daysSinceUpload =
        DateTime.now().difference(topic.createdAt).inDays;
    final recencyFactor = 1.0 / (1 + daysSinceUpload * 0.1);
    final followerFactor =
        topic.followerCount > 0 ? (topic.followerCount / 100).clamp(0, 5) : 0;
    final videoCountFactor =
        topic.videoCount > 0 ? (topic.videoCount / 10).clamp(0, 5) : 0;

    return recencyFactor * 5 + followerFactor * 3 + videoCountFactor * 2;
  }

  String get title {
    switch (type) {
      case ContentType.video:
        return video?.title ?? '';
      case ContentType.playlist:
        return playlist?.name ?? '';
      case ContentType.communityPost:
        return communityPost?.title ?? '';
      case ContentType.topic:
        return topic?.title ?? '';
    }
  }

  String get thumbnailUrl {
    switch (type) {
      case ContentType.video:
        return video?.thumbnailUrl ?? '';
      case ContentType.playlist:
        return playlist?.thumbnailUrl ?? '';
      case ContentType.communityPost:
        return communityPost?.images.isNotEmpty ?? false
            ? communityPost!.images.first
            : '';
      case ContentType.topic:
        return topic?.coverImage ?? topic?.thumbnailUrl ?? '';
    }
  }

  String get channelName {
    switch (type) {
      case ContentType.video:
        return video?.channelName ?? '';
      case ContentType.playlist:
        return ''; // Playlists don't have channel name directly
      case ContentType.communityPost:
        return communityPost?.channelName ?? '';
      case ContentType.topic:
        return '';
    }
  }

  String get channelImage {
    switch (type) {
      case ContentType.video:
        return video?.channelImage ?? '';
      case ContentType.playlist:
        return '';
      case ContentType.communityPost:
        return communityPost?.channelImage ?? '';
      case ContentType.topic:
        return '';
    }
  }
}
