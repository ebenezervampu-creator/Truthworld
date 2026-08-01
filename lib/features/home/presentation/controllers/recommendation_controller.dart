import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Recommendation controller managing carousel collections (recommended, trending, music)
class RecommendationController extends BaseController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final recommendedVideos = <Video>[].obs;
  final trendingVideos = <Video>[].obs;
  final musicVideos = <Video>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchCarouselContent();
  }

  Future<void> fetchCarouselContent() async {
    setViewState(ViewState.loading);
    try {
      logApi('fetchCarouselContent');
      final results = await Future.wait([
        _fetchPublicVideos(10),
        _fetchPublicVideos(10),
        _fetchCategoryVideos('Music', 10),
      ]);

      recommendedVideos.assignAll(results[0]);
      trendingVideos.assignAll(results[1]);
      musicVideos.assignAll(results[2]);
      setViewState(ViewState.success);
    } catch (e) {
      handleError(e);
    }
  }

  Future<List<Video>> _fetchPublicVideos(int limit) async {
    final snap = await _firestore
        .collection(FirestoreCollections.videos)
        .limit(limit)
        .get();
    return snap.docs.map(Video.fromDocumentSnapshot).toList();
  }

  Future<List<Video>> _fetchCategoryVideos(String category, int limit) async {
    final snap = await _firestore
        .collection(FirestoreCollections.videos)
        .where('category', isEqualTo: category)
        .limit(limit)
        .get();
    return snap.docs.map(Video.fromDocumentSnapshot).toList();
  }
}
