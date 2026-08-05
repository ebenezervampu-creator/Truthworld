import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/base/base_repository.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/repositories/analytics_repository.dart';

class AnalyticsRepositoryImpl extends BaseRepository implements AnalyticsRepository {
  final FirebaseFirestore _firestore;

  AnalyticsRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<Result<Map<String, dynamic>>> getChannelOverview(
    String channelId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return safeFetch(() async {
      final doc = await _firestore.collection(FirestoreCollections.analytics).doc(channelId).get();
      if (!doc.exists) return {};
      return doc.data()!;
    });
  }

  @override
  Future<Result<Map<String, dynamic>>> getViewsAnalytics(
    String channelId, {
    required DateTime startDate,
    required DateTime endDate,
    String granularity = 'day',
  }) async {
    return safeFetch(() async {
      final doc = await _firestore.collection(FirestoreCollections.analytics)
          .doc(channelId)
          .collection('views')
          .doc(granularity)
          .get();
      if (!doc.exists) return {};
      return doc.data()!;
    });
  }

  @override
  Future<Result<Map<String, dynamic>>> getWatchTimeAnalytics(
    String channelId, {
    required DateTime startDate,
    required DateTime endDate,
    String granularity = 'day',
  }) async {
    return safeFetch(() async {
      final doc = await _firestore.collection(FirestoreCollections.analytics)
          .doc(channelId)
          .collection('watch_time')
          .doc(granularity)
          .get();
      if (!doc.exists) return {};
      return doc.data()!;
    });
  }

  @override
  Future<Result<Map<String, dynamic>>> getSubscriberAnalytics(
    String channelId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return safeFetch(() async {
      final doc = await _firestore.collection(FirestoreCollections.analytics)
          .doc(channelId)
          .collection('subscribers')
          .doc('growth')
          .get();
      if (!doc.exists) return {};
      return doc.data()!;
    });
  }

  @override
  Future<Result<Map<String, dynamic>>> getGeographicData(String channelId) async {
    return safeFetch(() async {
      final doc = await _firestore.collection(FirestoreCollections.analytics)
          .doc(channelId)
          .collection('demographics')
          .doc('geography')
          .get();
      if (!doc.exists) return {};
      return doc.data()!;
    });
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getTopVideos(
    String channelId, {
    int limit = 10,
    String sortBy = 'views',
  }) async {
    return safeFetch(() async {
      final snapshot = await _firestore.collection('video_analytics')
          .where('channelId', isEqualTo: channelId)
          .orderBy(sortBy, descending: true)
          .limit(limit)
          .get();
          
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  @override
  Future<Result<int>> getRealTimeViewers(String channelId) async {
    return safeFetch(() async {
      final doc = await _firestore.collection(FirestoreCollections.analytics)
          .doc(channelId)
          .collection('realtime')
          .doc('viewers')
          .get();
      if (!doc.exists) return 0;
      return doc.data()?['count'] as int? ?? 0;
    });
  }
}
