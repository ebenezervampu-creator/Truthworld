import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/repositories/dashboard_repository.dart';

class FakeDashboardRepository implements DashboardRepository {
  final List<Map<String, dynamic>> mockVideos = [
    {'id': 'v1', 'title': 'Video 1', 'channelId': 'c1', 'status': 'published'},
    {'id': 'v2', 'title': 'Video 2', 'channelId': 'c1', 'status': 'draft'},
  ];

  @override
  Future<Result<List<Map<String, dynamic>>>> getChannelVideos(
    String channelId, {
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    final filtered = mockVideos.where((v) {
      final matchesChannel = v['channelId'] == channelId;
      final matchesStatus = status == null || v['status'] == status;
      return matchesChannel && matchesStatus;
    }).toList();
    return Result.success(filtered);
  }

  @override
  Future<Result<Map<String, dynamic>>> getChannelAnalytics(
    String channelId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return Result.success({
      'totalViews': 12500,
      'totalWatchTimeMinutes': 48000,
      'totalSubscribersGained': 350,
    });
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getVideoComments(
    String videoId, {
    int page = 1,
    int limit = 20,
    String? filter,
  }) async {
    return Result.success([
      {'id': 'c1', 'videoId': videoId, 'text': 'Great content!'}
    ]);
  }

  @override
  Future<Result<void>> replyToComment(
    String videoId,
    String commentId,
    String replyText, {
    required String channelId,
    required String channelName,
    required String channelImageUrl,
  }) async {
    return Result.success(null);
  }

  @override
  Future<Result<Map<String, String>>> getVideoSubtitles(String videoId) async {
    return Result.success({'en': 'Hello world transcript'});
  }

  @override
  Future<Result<void>> saveVideoSubtitles(
    String videoId,
    Map<String, String> subtitles,
  ) async {
    return Result.success(null);
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getVideoChapters(String videoId) async {
    return Result.success([
      {'title': 'Intro', 'timestampMs': 0}
    ]);
  }

  @override
  Future<Result<void>> saveVideoChapters(
    String videoId,
    List<Map<String, dynamic>> chapters,
  ) async {
    return Result.success(null);
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getAudioTracks(String videoId) async {
    return Result.success([]);
  }

  @override
  Future<Result<void>> trashVideo(String videoId) async {
    return Result.success(null);
  }

  @override
  Future<Result<void>> restoreVideo(String videoId) async {
    return Result.success(null);
  }

  @override
  Future<Result<void>> permanentlyDeleteVideo(String videoId) async {
    mockVideos.removeWhere((v) => v['id'] == videoId);
    return Result.success(null);
  }

  @override
  Future<Result<Map<String, dynamic>>> getAudienceDemographics(String channelId) async {
    return Result.success({
      'topCountries': ['US', 'IN', 'GB'],
      'ageRange': {'18-24': 40, '25-34': 45},
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DashboardRepository Unit Tests', () {
    late FakeDashboardRepository repository;

    setUp(() {
      repository = FakeDashboardRepository();
    });

    test('getChannelVideos filters by channel and status', () async {
      final result = await repository.getChannelVideos('c1', status: 'published');
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.length, equals(1));
      expect(result.dataOrNull?.first['id'], equals('v1'));
    });

    test('getChannelAnalytics returns channel metrics', () async {
      final result = await repository.getChannelAnalytics(
        'c1',
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        endDate: DateTime.now(),
      );
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?['totalViews'], equals(12500));
    });

    test('permanentlyDeleteVideo removes video', () async {
      await repository.permanentlyDeleteVideo('v1');
      final list = await repository.getChannelVideos('c1');
      expect(list.dataOrNull?.length, equals(1));
    });

    test('getAudienceDemographics returns country breakdown', () async {
      final result = await repository.getAudienceDemographics('c1');
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?['topCountries'], contains('IN'));
    });
  });
}
