import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/base/base_repository.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/repositories/watchtime_repository.dart';

class WatchTimeRepositoryImpl extends BaseRepository implements WatchTimeRepository {
  final FirebaseFirestore _firestore;

  WatchTimeRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<Result<void>> recordWatchTime({
    required String userId,
    required String videoId,
    required int watchedSeconds,
    required int totalSeconds,
    required DateTime watchedAt,
  }) async {
    return safeSave(
      _firestore.collection('watch_sessions').doc(),
      {
        'userId': userId,
        'videoId': videoId,
        'watchedSeconds': watchedSeconds,
        'totalSeconds': totalSeconds,
        'watchedAt': Timestamp.fromDate(watchedAt),
        'createdAt': FieldValue.serverTimestamp(),
      },
    );
  }

  @override
  Future<Result<Map<String, dynamic>>> getUserWatchTimeSummary(
    String userId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return safeFetch(() async {
      final snapshot = await _firestore
          .collection('watch_sessions')
          .where('userId', isEqualTo: userId)
          .where('watchedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('watchedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      var totalSeconds = 0;
      for (final doc in snapshot.docs) {
        totalSeconds += (doc.data()['watchedSeconds'] as num? ?? 0).toInt();
      }

      return {
        'userId': userId,
        'totalSeconds': totalSeconds,
        'totalHours': totalSeconds / 3600.0,
        'sessionCount': snapshot.docs.length,
      };
    });
  }

  @override
  Future<Result<Map<String, dynamic>>> getChannelWatchTime(
    String channelId, {
    required DateTime startDate,
    required DateTime endDate,
    String granularity = 'day',
  }) async {
    return safeFetch(() async {
      final snapshot = await _firestore
          .collection('watch_sessions')
          .where('channelId', isEqualTo: channelId)
          .where('watchedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('watchedAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      var totalSeconds = 0;
      for (final doc in snapshot.docs) {
        totalSeconds += (doc.data()['watchedSeconds'] as num? ?? 0).toInt();
      }

      return {
        'channelId': channelId,
        'totalSeconds': totalSeconds,
        'totalHours': totalSeconds / 3600.0,
        'sessionCount': snapshot.docs.length,
        'granularity': granularity,
      };
    });
  }

  @override
  Future<Result<Map<String, double>>> getAverageWatchDuration(
    String channelId, {
    int limit = 20,
  }) async {
    return safeFetch(() async {
      final snapshot = await _firestore
          .collection('watch_sessions')
          .where('channelId', isEqualTo: channelId)
          .limit(100)
          .get();

      final videoDurations = <String, List<int>>{};
      for (final doc in snapshot.docs) {
        final vId = doc.data()['videoId'] as String? ?? '';
        final secs = (doc.data()['watchedSeconds'] as num? ?? 0).toInt();
        if (vId.isNotEmpty) {
          videoDurations.putIfAbsent(vId, () => []).add(secs);
        }
      }

      final result = <String, double>{};
      videoDurations.forEach((vId, list) {
        final avg = list.reduce((a, b) => a + b) / list.length;
        result[vId] = avg;
      });

      return result;
    });
  }
}
