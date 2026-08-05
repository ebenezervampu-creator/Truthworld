import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/repositories/library_repository.dart';

class FakeLibraryRepository implements LibraryRepository {
  final List<String> likedVideoIds = ['v1', 'v2'];
  final List<Map<String, dynamic>> watchHistory = [
    {'videoId': 'v1', 'watchedSeconds': 120, 'totalSeconds': 300},
  ];
  final List<String> watchLaterIds = ['v3'];

  @override
  Future<Result<List<Map<String, dynamic>>>> getLikedVideos(
    String userId, {
    int page = 1,
    int limit = 20,
  }) async {
    return Result.success(
      likedVideoIds.map((id) => {'id': id, 'title': 'Video $id'}).toList(),
    );
  }

  @override
  Future<Result<void>> toggleLikeVideo(String userId, String videoId) async {
    if (likedVideoIds.contains(videoId)) {
      likedVideoIds.remove(videoId);
    } else {
      likedVideoIds.add(videoId);
    }
    return Result.success(null);
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getWatchHistory(
    String userId, {
    int page = 1,
    int limit = 20,
  }) async {
    return Result.success(watchHistory);
  }

  @override
  Future<Result<void>> addToWatchHistory(
    String userId,
    String videoId, {
    int watchedSeconds = 0,
    int totalSeconds = 0,
  }) async {
    watchHistory.add({
      'videoId': videoId,
      'watchedSeconds': watchedSeconds,
      'totalSeconds': totalSeconds,
    });
    return Result.success(null);
  }

  @override
  Future<Result<void>> clearWatchHistory(String userId) async {
    watchHistory.clear();
    return Result.success(null);
  }

  @override
  Future<Result<void>> removeFromWatchHistory(String userId, String videoId) async {
    watchHistory.removeWhere((item) => item['videoId'] == videoId);
    return Result.success(null);
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getWatchLater(
    String userId, {
    int page = 1,
    int limit = 20,
  }) async {
    return Result.success(
      watchLaterIds.map((id) => {'id': id, 'title': 'Watch Later $id'}).toList(),
    );
  }

  @override
  Future<Result<void>> toggleWatchLater(String userId, String videoId) async {
    if (watchLaterIds.contains(videoId)) {
      watchLaterIds.remove(videoId);
    } else {
      watchLaterIds.add(videoId);
    }
    return Result.success(null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LibraryRepository Unit Tests', () {
    late FakeLibraryRepository repository;

    setUp(() {
      repository = FakeLibraryRepository();
    });

    test('getLikedVideos returns liked video items', () async {
      final result = await repository.getLikedVideos('u1');
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.length, equals(2));
    });

    test('toggleLikeVideo toggles like state', () async {
      await repository.toggleLikeVideo('u1', 'v1'); // remove v1
      final result = await repository.getLikedVideos('u1');
      expect(result.dataOrNull?.length, equals(1));

      await repository.toggleLikeVideo('u1', 'v4'); // add v4
      final updated = await repository.getLikedVideos('u1');
      expect(updated.dataOrNull?.length, equals(2));
    });

    test('addToWatchHistory records view progress', () async {
      await repository.addToWatchHistory('u1', 'v99', watchedSeconds: 30, totalSeconds: 60);
      final history = await repository.getWatchHistory('u1');
      expect(history.dataOrNull?.length, equals(2));
    });

    test('clearWatchHistory empties watch history list', () async {
      await repository.clearWatchHistory('u1');
      final history = await repository.getWatchHistory('u1');
      expect(history.dataOrNull, isEmpty);
    });
  });
}
