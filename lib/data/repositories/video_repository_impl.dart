import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_repository.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/core/services/distributed_counter_service.dart';
import 'package:truthworld/data/datasources/remote/video_remote_datasource.dart';
import 'package:truthworld/domain/entities/video_entity.dart';
import 'package:truthworld/domain/repositories/video_repository.dart';
import 'package:truthworld/features/video/data/models/video.dart';

class VideoRepositoryImpl extends BaseRepository implements VideoRepository {
  final VideoRemoteDataSource _remoteDataSource;

  VideoRepositoryImpl({
    FirebaseFirestore? firestore,
    VideoRemoteDataSource? remoteDataSource,
  }) : _remoteDataSource = remoteDataSource ??
            FirestoreVideoRemoteDataSource(firestore: firestore);

  VideoEntity _mapToEntity(Video model) {
    return model.toEntity();
  }

  @override
  Future<Result<List<VideoEntity>>> getHomeFeed({
    int page = 1,
    int limit = 10,
    dynamic startAfter,
  }) async {
    return safeFetch(() async {
      final videos = await _remoteDataSource.getHomeFeed(
        limit: limit,
        startAfter: startAfter,
      );
      return videos.map(_mapToEntity).toList();
    });
  }

  @override
  Future<Result<VideoEntity>> getVideoById(String id) async {
    return safeFetch(() async {
      final video = await _remoteDataSource.getVideoById(id);
      return _mapToEntity(video);
    });
  }

  @override
  Future<Result<List<VideoEntity>>> searchVideos(
    String query, {
    int page = 1,
    int limit = 20,
    dynamic startAfter,
  }) async {
    return safeFetch(() async {
      final videos = await _remoteDataSource.searchVideos(
        query,
        limit: limit,
        startAfter: startAfter,
      );
      return videos.map(_mapToEntity).toList();
    });
  }

  @override
  Future<Result<List<VideoEntity>>> getVideosByChannel(
    String channelId, {
    int page = 1,
    int limit = 20,
    dynamic startAfter,
  }) async {
    return safeFetch(() async {
      final videos = await _remoteDataSource.getVideosByChannel(
        channelId,
        limit: limit,
        startAfter: startAfter,
      );
      return videos.map(_mapToEntity).toList();
    });
  }

  @override
  Future<Result<List<VideoEntity>>> getTrendingVideos({int limit = 20}) async {
    return safeFetch(() async {
      final videos = await _remoteDataSource.getTrendingVideos(limit: limit);
      return videos.map(_mapToEntity).toList();
    });
  }

  @override
  Future<Result<void>> toggleLike(String videoId, String userId) async {
    return safeFetch(() => _remoteDataSource.toggleLike(videoId, userId));
  }

  @override
  Future<Result<void>> toggleDislike(String videoId, String userId) async {
    return safeFetch(() => _remoteDataSource.toggleDislike(videoId, userId));
  }

  @override
  Future<Result<void>> deleteVideo(String videoId) async {
    return safeFetch(() => _remoteDataSource.deleteVideo(videoId));
  }

  @override
  Future<Result<void>> incrementViewCount(String videoId) async {
    try {
      final counterService = Get.isRegistered<DistributedCounterService>()
          ? DistributedCounterService.to
          : Get.put(DistributedCounterService());
      await counterService.incrementVideoViews(videoId: videoId);
      return Result.success(null);
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'VideoRepositoryImpl.incrementViewCount',
      );
      return Result.failure(AppException.from(e, stackTrace));
    }
  }
}
