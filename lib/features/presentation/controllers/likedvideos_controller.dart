import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/video.dart'; // Adjust import as needed

class LikedVideosController extends GetxController {
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  // Observable state variables
  RxBool isListView = true.obs;
  RxString searchQuery = ''.obs;
  RxBool isSearching = false.obs;
  RxString sortBy = 'recent'.obs;
  RxBool isAscending = false.obs;

  // Observable data variables
  RxList<Video> videos = <Video>[].obs;
  RxBool isLoading = true.obs;
  RxString errorMessage = ''.obs;

  StreamSubscription<QuerySnapshot>? _subscription;

  @override
  void onInit() {
    super.onInit();
    _listenToVideos();
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }

  void _listenToVideos() {
    isLoading.value = true;
    errorMessage.value = '';
    // Use reverse index subcollection for scalable queries
    // Pattern: users/{userId}/likedVideos/{videoId}
    _subscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('likedVideos')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(
          (snapshot) async {
            if (snapshot.docs.isEmpty) {
              videos.value = [];
              isLoading.value = false;
              return;
            }

            // Firestore whereIn limit: max 10 items per query
            // Must batch for users with >10 liked videos
            final videoIds = snapshot.docs.map((d) => d.id).toList();
            final videoDocs = await _fetchVideosInBatches(videoIds);

            videos.value = videoDocs;
            isLoading.value = false;
          },
          onError: (error) {
            errorMessage.value = error.toString();
            isLoading.value = false;
          },
        );
  }

  /// Batch video fetches to respect Firestore whereIn limit (max 10)
  Future<List<Video>> _fetchVideosInBatches(List<String> videoIds) async {
    const batchSize = 10;
    final allVideos = <Video>[];

    for (var i = 0; i < videoIds.length; i += batchSize) {
      final batch = videoIds.sublist(
        i,
        i + batchSize > videoIds.length ? videoIds.length : i + batchSize,
      );

      final batchDocs = await FirebaseFirestore.instance
          .collection('videos')
          .where(FieldPath.documentId, whereIn: batch)
          .get();

      allVideos.addAll(
        batchDocs.docs.map(Video.fromDocumentSnapshot),
      );
    }

    return allVideos;
  }

  void toggleView() {
    isListView.value = !isListView.value;
  }

  void setSearchQuery(String query) {
    searchQuery.value = query;
  }

  void toggleSearching() {
    isSearching.value = !isSearching.value;
    if (!isSearching.value) {
      searchQuery.value = '';
    }
  }

  void setSortBy(String value) {
    if (sortBy.value == value) {
      isAscending.value = !isAscending.value;
    } else {
      sortBy.value = value;
      isAscending.value = false;
    }
  }

  void retryFetch() {
    _subscription?.cancel();
    _listenToVideos();
  }

  List<Video> get filteredAndSortedVideos {
    var filtered = videos.toList();
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((video) {
        return video.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
            video.description.toLowerCase().contains(searchQuery.toLowerCase());
      }).toList();
    }
    switch (sortBy.value) {
      case 'recent':
        filtered.sort(
          (a, b) => isAscending.value
              ? a.uploadedAt.compareTo(b.uploadedAt)
              : b.uploadedAt.compareTo(a.uploadedAt),
        );
      case 'views':
        filtered.sort(
          (a, b) => isAscending.value
              ? a.views.compareTo(b.views)
              : b.views.compareTo(a.views),
        );
      case 'likes':
        filtered.sort(
          (a, b) => isAscending.value
              ? a.likeCount.compareTo(b.likeCount)
              : b.likeCount.compareTo(a.likeCount),
        );
      case 'title':
        filtered.sort(
          (a, b) => isAscending.value
              ? a.title.compareTo(b.title)
              : b.title.compareTo(a.title),
        );
    }
    return filtered;
  }
}
