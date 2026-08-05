import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/repositories/analytics_repository.dart';

class FakeAnalyticsRepository implements AnalyticsRepository {
  @override
  Future<Result<Map<String, dynamic>>> getChannelOverview(String channelId, {required DateTime startDate, required DateTime endDate}) async {
    return Result.success({'views': 1000, 'watchTime': 500});
  }

  @override
  Future<Result<Map<String, dynamic>>> getViewsAnalytics(String channelId, {required DateTime startDate, required DateTime endDate, String granularity = 'day'}) async {
    return Result.success({'data': [10, 20, 30]});
  }

  @override
  Future<Result<Map<String, dynamic>>> getWatchTimeAnalytics(String channelId, {required DateTime startDate, required DateTime endDate, String granularity = 'day'}) async {
    return Result.success({'data': [5, 10, 15]});
  }

  @override
  Future<Result<Map<String, dynamic>>> getSubscriberAnalytics(String channelId, {required DateTime startDate, required DateTime endDate}) async {
    return Result.success({'gained': 50, 'lost': 10});
  }

  @override
  Future<Result<Map<String, dynamic>>> getGeographicData(String channelId) async {
    return Result.success({'US': 500, 'IN': 300});
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getTopVideos(String channelId, {int limit = 10, String sortBy = 'views'}) async {
    return Result.success([{'id': 'v1', 'views': 100}]);
  }

  @override
  Future<Result<int>> getRealTimeViewers(String channelId) async {
    return Result.success(42);
  }
}

void main() {
  group('AnalyticsRepository Unit Tests', () {
    late FakeAnalyticsRepository repository;

    setUp(() {
      repository = FakeAnalyticsRepository();
    });

    test('getChannelOverview returns data', () async {
      final result = await repository.getChannelOverview('c1', startDate: DateTime.now(), endDate: DateTime.now());
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?['views'], equals(1000));
    });

    test('getViewsAnalytics returns time-series data', () async {
      final result = await repository.getViewsAnalytics('c1', startDate: DateTime.now(), endDate: DateTime.now());
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?['data'], isNotEmpty);
    });

    test('getWatchTimeAnalytics returns data', () async {
      final result = await repository.getWatchTimeAnalytics('c1', startDate: DateTime.now(), endDate: DateTime.now());
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?['data'], isNotEmpty);
    });

    test('getSubscriberAnalytics returns data', () async {
      final result = await repository.getSubscriberAnalytics('c1', startDate: DateTime.now(), endDate: DateTime.now());
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?['gained'], equals(50));
    });

    test('getGeographicData returns countries', () async {
      final result = await repository.getGeographicData('c1');
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?['US'], equals(500));
    });

    test('getTopVideos returns videos', () async {
      final result = await repository.getTopVideos('c1');
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.length, equals(1));
      expect(result.dataOrNull?.first['id'], equals('v1'));
    });

    test('getRealTimeViewers returns count', () async {
      final result = await repository.getRealTimeViewers('c1');
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, equals(42));
    });
  });
}
