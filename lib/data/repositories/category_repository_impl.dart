import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/base/base_repository.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/repositories/category_repository.dart';

class CategoryRepositoryImpl extends BaseRepository implements CategoryRepository {
  final FirebaseFirestore _firestore;

  CategoryRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<Result<List<Map<String, dynamic>>>> getCategories() async {
    return safeFetch(() async {
      final snapshot = await _firestore
          .collection(FirestoreCollections.categories)
          .orderBy('name')
          .get();

      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    });
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getVideosByCategory(
    String category, {
    int page = 1,
    int limit = 20,
    String sortBy = 'trending',
  }) async {
    return safeFetch(() async {
      var query = _firestore
          .collection(FirestoreCollections.videos)
          .where('category', isEqualTo: category)
          .where('visibility', isEqualTo: 'public');

      if (sortBy == 'popular' || sortBy == 'trending') {
        query = query.orderBy('viewCount', descending: true);
      } else {
        query = query.orderBy('createdAt', descending: true);
      }

      final snapshot = await query.limit(limit).get();
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    });
  }

  @override
  Future<Result<Map<String, dynamic>>> getCategoryInsights(String category) async {
    return safeFetch(() async {
      final doc = await _firestore
          .collection(FirestoreCollections.categories)
          .doc(category)
          .get();

      if (!doc.exists) {
        return <String, dynamic>{'category': category, 'totalVideos': 0, 'totalViews': 0};
      }

      return {'id': doc.id, ...doc.data()!};
    });
  }
}
