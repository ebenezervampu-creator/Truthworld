import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/video.dart';

class WatchHistoryController extends GetxController
    with GetTickerProviderStateMixin {
  // Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // UI State
  final isLoading = true.obs;
  final hasError = false.obs;
  final errorMessage = ''.obs;
  final isListView = true.obs;
  final isSearching = false.obs;

  // Data
  final videos = <Video>[].obs;
  final filteredVideos = <Video>[].obs;

  // Sorting
  final sortBy = 'recent'.obs;
  final isAscending = false.obs;

  // Controllers
  late ScrollController scrollController;
  late TextEditingController searchController;
  late AnimationController _fabAnimationController;
  late AnimationController _fadeAnimationController;
  late AnimationController _searchAnimationController;

  // Animations
  late Animation<double> fabAnimation;
  late Animation<double> fadeAnimation;
  late Animation<double> searchAnimation;

  @override
  void onInit() {
    super.onInit();
    // Initialize controllers
    scrollController = ScrollController();
    searchController = TextEditingController();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _searchAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Initialize animations
    fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    );
    fadeAnimation = CurvedAnimation(
      parent: _fadeAnimationController,
      curve: Curves.easeIn,
    );
    searchAnimation = CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeInOut,
    );

    // Add listeners
    searchController.addListener(_onSearchChanged);
    scrollController.addListener(_onScroll);

    // Initial actions
    loadWatchHistory();
    _fadeAnimationController.forward();
  }

  @override
  void onClose() {
    // Dispose controllers
    scrollController.dispose();
    searchController.dispose();
    _fabAnimationController.dispose();
    _fadeAnimationController.dispose();
    _searchAnimationController.dispose();
    super.onClose();
  }

  void _onScroll() {
    if (scrollController.offset > 100) {
      _fabAnimationController.forward();
    } else {
      _fabAnimationController.reverse();
    }
  }

  Future<void> loadWatchHistory() async {
    try {
      isLoading(true);
      hasError(false);
      final user = _auth.currentUser;
      if (user == null) {
        // Not logged in, handled by UI
        isLoading(false);
        return;
      }

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('views')
          .orderBy('watchedAt', descending: true)
          .get();

      final videoList = snapshot.docs
          .map(Video.fromDocumentSnapshot)
          .toList();
      videos.assignAll(videoList);
      _applyFiltersAndSort();
    } catch (e) {
      hasError(true);
      errorMessage('Failed to load history: $e');
      printError(info: e.toString());
    } finally {
      isLoading(false);
    }
  }

  void _onSearchChanged() {
    _applyFiltersAndSort();
  }

  void setSortBy(String criteria) {
    if (sortBy.value == criteria) {
      isAscending.toggle();
    } else {
      sortBy(criteria);
      isAscending(false); // Default to descending for new criteria
    }
    _applyFiltersAndSort();
  }

  void _applyFiltersAndSort() {
    var tempVideos = List<Video>.from(videos);

    // Filtering
    if (searchController.text.isNotEmpty) {
      final query = searchController.text.toLowerCase();
      tempVideos = tempVideos.where((video) {
        return video.title.toLowerCase().contains(query) ||
            video.description.toLowerCase().contains(query) ||
            video.ownerId.toLowerCase().contains(query);
      }).toList();
    }

    // Sorting
    tempVideos.sort((a, b) {
      int comparison;
      switch (sortBy.value) {
        case 'views':
          comparison = a.views.compareTo(b.views);
        case 'likes':
          comparison = a.likeCount.compareTo(b.likeCount);
        case 'title':
          comparison = a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case 'recent':
        default:
          comparison = a.uploadedAt.compareTo(b.uploadedAt);
      }
      return isAscending.value ? comparison : -comparison;
    });

    filteredVideos.assignAll(tempVideos);
  }

  void toggleViewMode() {
    isListView.toggle();
  }

  void toggleSearch() {
    isSearching.toggle();
    if (isSearching.value) {
      _searchAnimationController.forward();
    } else {
      _searchAnimationController.reverse();
      searchController.clear();
    }
  }

  void navigateToVideo(Video video) {
    Get.toNamed('/watch?v=${video.id}', arguments: {'video': video});
  }

  void navigateToHome() {
    // Implement navigation to home/browse screen
    Get.snackbar('Navigate', 'To Home Screen');
  }

  void navigateToAuth() {
    // Implement navigation to authentication screen
    Get.snackbar('Navigate', 'To Auth Screen');
  }
}





