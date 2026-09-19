import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/entities/channel_entity.dart';
import 'package:truthworld/domain/entities/topic_entity.dart';
import 'package:truthworld/domain/entities/video_entity.dart';

/// Repository interface for trending content operations.
abstract class TrendingRepository {
  /// Fetch trending videos with pagination.
  Future<Result<List<VideoEntity>>> getTrendingVideos({
    int page = 1,
    int limit = 20,
    String? country,
    String? category,
  });

  /// Fetch trending topics.
  Future<Result<List<TopicEntity>>> getTrendingTopics({
    int limit = 10,
  });

  /// Fetch trending creators.
  Future<Result<List<ChannelEntity>>> getTrendingCreators({
    int limit = 10,
  });
}
