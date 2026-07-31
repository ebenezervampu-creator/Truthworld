import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/base/paged_controller.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/features/community/data/models/community_post_model.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Feed controller handling infinite scroll, category filtering, and community post mixing.
class FeedController extends PagedController<Video> {
  FeedController() : super(pageSize: 24);
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final selectedCategory = 'All'.obs;
  final communityPosts = <CommunityPostModel>[].obs;
  final mixedFeedItems = <dynamic>[].obs;

  DocumentSnapshot? _lastDocument;

  @override
  void onInit() {
    super.onInit();
    addWorker(
      ever(selectedCategory, (String category) {
        logInit();
        loadInitialData();
      }),
    );
  }

  void setCategory(String category) {
    if (selectedCategory.value != category) {
      selectedCategory.value = category;
    }
  }

  @override
  Future<Result<List<Video>>> fetchPageData(int page) async {
    return safeFetchVideos(page);
  }

  Future<Result<List<Video>>> safeFetchVideos(int page) async {
    try {
      logApi('fetchVideos (page: $page, category: ${selectedCategory.value})');
      Query query = _firestore
          .collection('videos')
          .orderBy('uploadedAt', descending: true);

      if (selectedCategory.value != 'All') {
        query = query.where('category', isEqualTo: selectedCategory.value);
      }

      if (page > 1 && _lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.limit(pageSize).get();
      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }

      final fetchedVideos = snapshot.docs
          .map(Video.fromDocumentSnapshot)
          .toList();
      return Result.success(fetchedVideos);
    } catch (e) {
      logException(e);
      return Result.failure(
        GenericAppException(message: e.toString(), originalException: e),
      );
    }
  }
}
