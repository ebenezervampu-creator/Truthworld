import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/base/base_repository.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/repositories/trending_repository.dart';

class TrendingRepositoryImpl extends BaseRepository implements TrendingRepository {
  final FirebaseFirestore _firestore;

  TrendingRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<Result<List<Map<String, dynamic>>>> getTrendingVideos({
    int page = 1,
    int limit = 20,
    String? country,
    String? category,
  }) async {
    return safeFetch(() async {
      Query query = _firestore
          .collection(FirestoreCollections.videos)
          .where('visibility', isEqualTo: 'public');

      if (category != null && category.isNotEmpty) {
        query = query.where('category', isEqualTo: category);
      }

      query = query.orderBy('viewCount', descending: true).limit(limit);

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()! as Map<String, dynamic>}).toList();
    });
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getTrendingTopics({
    int limit = 10,
  }) async {
    return safeFetch(() async {
      final snapshot = await _firestore
          .collection(FirestoreCollections.topics)
          .where('status', isEqualTo: 'active')
          .orderBy('followerCount', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .where((data) => ((data['videoCount'] as num?)?.toInt() ?? 0) > 0)
          .toList();
    });
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getTrendingCreators({
    int limit = 10,
  }) async {
    return safeFetch(() async {
      final snapshot = await _firestore
          .collection(FirestoreCollections.channels)
          .orderBy('subscriberCount', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    });
  }
}
