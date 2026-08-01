import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/entities/video_entity.dart';
import 'package:truthworld/domain/entities/channel_entity.dart';

abstract class SearchRepository {
  Future<Result<List<VideoEntity>>> searchVideos(
    String query, {
    int limit = 20,
    dynamic cursor,
  });

  Future<Result<List<ChannelEntity>>> searchChannels(
    String query, {
    int limit = 20,
    dynamic cursor,
  });
}
