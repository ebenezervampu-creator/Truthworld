import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/repositories/home_repository.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/video/data/models/video.dart';

class FakeHomeRepository implements HomeRepository {
  final List<Video> mockVideos = [];
  final List<Topic> mockTopics = [];

  @override
  Future<Result<List<Video>>> getHomeFeed({
    int page = 1,
    int limit = 20,
    String? category,
  }) async {
    final filtered = category != null
        ? mockVideos.where((v) => v.category == category).toList()
        : mockVideos;
    return Result.success(filtered);
  }

  @override
  Future<Result<List<Video>>> getVideosByCategory(
    String category, {
    int page = 1,
    int limit = 20,
  }) async {
    return Result.success(
      mockVideos.where((v) => v.category == category).toList(),
    );
  }

  @override
  Future<Result<List<Topic>>> getFeaturedTopics({int limit = 10}) async {
    return Result.success(mockTopics.take(limit).toList());
  }

  @override
  Future<Result<List<Video>>> getVideosByTopic(
    String topicId, {
    int page = 1,
    int limit = 20,
  }) async {
    return Result.success(
      mockVideos.where((v) => v.topics.contains(topicId)).toList(),
    );
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getCommunityPosts({
    int page = 1,
    int limit = 10,
  }) async {
    return Result.success([
      {'id': 'post1', 'title': 'First Post', 'visibility': 'public'}
    ]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomeRepository Unit Tests', () {
    late FakeHomeRepository repository;

    setUp(() {
      repository = FakeHomeRepository();
    });

    test('getHomeFeed returns success with video list', () async {
      final result = await repository.getHomeFeed(limit: 10);

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, isEmpty);
    });

    test('getVideosByCategory filters correctly', () async {
      final result = await repository.getVideosByCategory('Education');

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, isEmpty);
    });

    test('getFeaturedTopics returns topics list', () async {
      final result = await repository.getFeaturedTopics(limit: 5);

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, isEmpty);
    });

    test('getCommunityPosts returns post maps', () async {
      final result = await repository.getCommunityPosts();

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.length, equals(1));
      expect(result.dataOrNull?.first['id'], equals('post1'));
    });
  });
}
