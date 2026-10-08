import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/entities/channel_entity.dart';
import 'package:truthworld/domain/entities/topic_entity.dart';
import 'package:truthworld/domain/entities/video_entity.dart';
import 'package:truthworld/domain/repositories/trending_repository.dart';
import 'package:truthworld/domain/usecases/video/get_trending_videos_usecase.dart';
import 'package:truthworld/features/trending/presentation/controllers/trending_controller.dart';
import '../../test_helpers/mock_firebase.dart';

class MockTrendingRepository implements TrendingRepository {
  List<VideoEntity> videosToReturn = [];
  bool shouldThrow = false;

  @override
  Future<Result<List<VideoEntity>>> getTrendingVideos({
    int page = 1,
    int limit = 20,
    String? country,
    String? category,
  }) async {
    if (shouldThrow) {
      return Result.failure(const ServerException(message: 'Network error'));
    }
    return Result.success(videosToReturn);
  }

  @override
  Future<Result<List<ChannelEntity>>> getTrendingCreators({int limit = 10}) async {
    return Result.success([]);
  }

  @override
  Future<Result<List<TopicEntity>>> getTrendingTopics({int limit = 10}) async {
    return Result.success([]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  group('TrendingController Tests', () {
    late MockTrendingRepository mockRepo;
    late GetTrendingVideosUseCase useCase;

    setUp(() {
      Get.reset();
      mockRepo = MockTrendingRepository();
      useCase = GetTrendingVideosUseCase(mockRepo);
    });

    test('initializes and loads trending videos successfully', () async {
      final now = DateTime.now();
      mockRepo.videosToReturn = [
        VideoEntity(
          id: 'v1',
          title: 'Trending Video 1',
          description: 'Desc 1',
          thumbnailUrl: 'https://example.com/1.jpg',
          originalUrl: 'https://example.com/1.mp4',
          channelId: 'ch1',
          channelName: 'Channel One',
          ownerId: 'u1',
          viewCount: 5000,
          createdAt: now,
          updatedAt: now,
        ),
        VideoEntity(
          id: 'v2',
          title: 'Trending Video 2',
          description: 'Desc 2',
          thumbnailUrl: 'https://example.com/2.jpg',
          originalUrl: 'https://example.com/2.mp4',
          channelId: 'ch2',
          channelName: 'Channel Two',
          ownerId: 'u2',
          viewCount: 3000,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final controller = TrendingController(getTrendingVideosUseCase: useCase);
      await controller.fetchTrendingVideos();

      expect(controller.state, equals(ViewState.success));
      expect(controller.trendingVideos.length, equals(2));
      expect(controller.trendingVideos.first.id, equals('v1'));
      expect(controller.error.value, isEmpty);
    });

    test('handles empty trending video list gracefully', () async {
      mockRepo.videosToReturn = [];

      final controller = TrendingController(getTrendingVideosUseCase: useCase);
      await controller.fetchTrendingVideos();

      expect(controller.state, equals(ViewState.success));
      expect(controller.trendingVideos, isEmpty);
      expect(controller.error.value, isEmpty);
    });

    test('filters out non-ready/processing videos per visibility policy', () async {
      final now = DateTime.now();
      mockRepo.videosToReturn = [
        VideoEntity(
          id: 'v1',
          title: 'Public Ready',
          description: 'Desc 1',
          thumbnailUrl: 'https://example.com/1.jpg',
          originalUrl: 'https://example.com/1.mp4',
          channelId: 'ch1',
          channelName: 'Channel One',
          ownerId: 'u1',
          viewCount: 1000,
          createdAt: now,
          updatedAt: now,
        ),
        VideoEntity(
          id: 'v2',
          title: 'Processing Video',
          description: 'Desc 2',
          thumbnailUrl: 'https://example.com/2.jpg',
          channelId: 'ch2',
          channelName: 'Channel Two',
          ownerId: 'u2',
          viewCount: 1000,
          status: 'processing',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final controller = TrendingController(getTrendingVideosUseCase: useCase);
      await controller.fetchTrendingVideos();

      expect(controller.state, equals(ViewState.success));
      expect(controller.trendingVideos.length, equals(1));
      expect(controller.trendingVideos.first.id, equals('v1'));
    });

    test('handles fetch failure and exposes user-friendly error', () async {
      mockRepo.shouldThrow = true;

      final controller = TrendingController(getTrendingVideosUseCase: useCase);
      await controller.fetchTrendingVideos();

      expect(controller.state, equals(ViewState.error));
      expect(controller.trendingVideos, isEmpty);
      expect(controller.error.value, isNotEmpty);
    });
  });
}
