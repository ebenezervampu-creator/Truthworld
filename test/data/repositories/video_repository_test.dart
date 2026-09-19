import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/entities/video_entity.dart';
import 'package:truthworld/domain/repositories/video_repository.dart';
import 'package:truthworld/features/video/data/models/video.dart';

class FakeVideoRepository implements VideoRepository {
  final List<VideoEntity> videos = [];

  @override
  Future<Result<List<VideoEntity>>> getHomeFeed({
    int page = 1,
    int limit = 10,
    dynamic startAfter,
  }) async {
    return Result.success(videos.take(limit).toList());
  }

  @override
  Future<Result<VideoEntity>> getVideoById(String id) async {
    final match = videos.where((v) => v.id == id).toList();
    if (match.isEmpty) {
      return Result.failure(NotFoundException(message: 'Video not found: $id'));
    }
    return Result.success(match.first);
  }

  @override
  Future<Result<List<VideoEntity>>> searchVideos(
    String query, {
    int page = 1,
    int limit = 20,
    dynamic startAfter,
  }) async {
    final filtered = videos
        .where((v) => v.title.toLowerCase().contains(query.toLowerCase()))
        .take(limit)
        .toList();
    return Result.success(filtered);
  }

  @override
  Future<Result<List<VideoEntity>>> getVideosByChannel(
    String channelId, {
    int page = 1,
    int limit = 20,
    dynamic startAfter,
  }) async {
    final filtered = videos.where((v) => v.channelId == channelId).take(limit).toList();
    return Result.success(filtered);
  }

  @override
  Future<Result<List<VideoEntity>>> getTrendingVideos({int limit = 20}) async {
    return Result.success(videos.take(limit).toList());
  }

  @override
  Future<Result<void>> toggleLike(String videoId, String userId) async {
    return Result.success(null);
  }

  @override
  Future<Result<void>> toggleDislike(String videoId, String userId) async {
    return Result.success(null);
  }

  @override
  Future<Result<void>> deleteVideo(String videoId) async {
    videos.removeWhere((v) => v.id == videoId);
    return Result.success(null);
  }

  @override
  Future<Result<void>> incrementViewCount(String videoId) async {
    return Result.success(null);
  }
}

void main() {
  group('VideoRepository & Domain Entity Bridge Tests', () {
    late FakeVideoRepository repository;
    final now = DateTime(2026, 9, 19);

    final sampleEntity = VideoEntity(
      id: 'vid_123',
      title: 'Clean Architecture in Flutter',
      description: 'A deep dive into clean domain layers.',
      ownerId: 'user_456',
      channelId: 'chan_789',
      createdAt: now,
      updatedAt: now,
      channelName: 'TruthWorld Engineering',
      category: 'Technology',
      viewCount: 1500,
      likeCount: 120,
    );

    setUp(() {
      repository = FakeVideoRepository();
      repository.videos.add(sampleEntity);
    });

    test('VideoEntity correctly holds pure business properties and validates equality', () {
      expect(sampleEntity.id, 'vid_123');
      expect(sampleEntity.title, 'Clean Architecture in Flutter');
      expect(sampleEntity.category, 'Technology');
      expect(sampleEntity.viewCount, 1500);

      final identicalEntity = VideoEntity(
        id: 'vid_123',
        title: 'Different Title',
        ownerId: 'user_456',
        channelId: 'chan_789',
        createdAt: now,
        updatedAt: now,
      );
      expect(sampleEntity == identicalEntity, isTrue);
    });

    test('Video data model converts to pure VideoEntity seamlessly', () {
      final videoModel = Video(
        id: 'vid_999',
        title: 'Domain Modeling',
        description: 'Decoupled entities',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        ownerId: 'user_001',
        channelId: 'chan_001',
        channelName: 'TruthWorld',
        category: 'Education',
        tags: ['architecture', 'flutter'],
        createdAt: now,
        updatedAt: now,
        viewCount: 50,
        likeCount: 5,
      );

      final entity = videoModel.toEntity();

      expect(entity.id, 'vid_999');
      expect(entity.title, 'Domain Modeling');
      expect(entity.ownerId, 'user_001');
      expect(entity.tags, contains('architecture'));
    });

    test('Video data model round-trips from pure VideoEntity', () {
      final model = Video.fromEntity(sampleEntity);
      expect(model.id, sampleEntity.id);
      expect(model.title, sampleEntity.title);
      expect(model.channelName, sampleEntity.channelName);

      final reEntity = model.toEntity();
      expect(reEntity.id, sampleEntity.id);
      expect(reEntity.title, sampleEntity.title);
    });

    test('getVideoById returns success when video exists', () async {
      final result = await repository.getVideoById('vid_123');
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.title, 'Clean Architecture in Flutter');
    });

    test('getVideoById returns failure NotFoundException when video is missing', () async {
      final result = await repository.getVideoById('vid_non_existent');
      expect(result.isSuccess, isFalse);
      expect(result.exceptionOrNull, isA<NotFoundException>());
    });

    test('searchVideos queries and filters videos matching title', () async {
      final result = await repository.searchVideos('Flutter');
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.length, 1);
      expect(result.dataOrNull?.first.id, 'vid_123');
    });

    test('deleteVideo removes the video from repository store', () async {
      final deleteResult = await repository.deleteVideo('vid_123');
      expect(deleteResult.isSuccess, isTrue);

      final queryResult = await repository.getVideoById('vid_123');
      expect(queryResult.isSuccess, isFalse);
    });
  });
}
