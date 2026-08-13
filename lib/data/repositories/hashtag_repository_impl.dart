import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/base/base_repository.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/repositories/hashtag_repository.dart';

class HashtagRepositoryImpl extends BaseRepository implements HashtagRepository {
  final FirebaseFirestore _firestore;

  HashtagRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<Result<List<Map<String, dynamic>>>> getTrendingHashtags({
    int limit = 20,
  }) async {
    return safeFetch(() async {
      final snapshot = await _firestore
          .collection(FirestoreCollections.hashtags)
          .orderBy('usageCount', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    });
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getVideosByHashtag(
    String hashtag, {
    int page = 1,
    int limit = 20,
  }) async {
    return safeFetch(() async {
      final formattedTag = hashtag.startsWith('#') ? hashtag : '#$hashtag';
      final snapshot = await _firestore
          .collection(FirestoreCollections.videos)
          .where('tags', arrayContains: formattedTag)
          .where('visibility', isEqualTo: 'public')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    });
  }

  @override
  Future<Result<List<String>>> searchHashtags(String query, {int limit = 10}) async {
    return safeFetch(() async {
      final cleanQuery = query.replaceAll('#', '').toLowerCase();
      final snapshot = await _firestore
          .collection(FirestoreCollections.hashtags)
          .where('tagLowercase', isGreaterThanOrEqualTo: cleanQuery)
          .where('tagLowercase', isLessThanOrEqualTo: '$cleanQuery\uf8ff')
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => doc.data()['name'] as String? ?? doc.id)
          .toList();
    });
  }
}
