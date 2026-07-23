import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/services/feedback/feedback_service.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/data/repositories/topic_repository.dart';

import 'package:truthworld/features/topics/presentation/controllers/topic_controller.dart';

/// GetX Controller for the Topic Discovery Platform UI
class ExploreTopicsController extends GetxController {

  ExploreTopicsController({TopicRepository? repository})
    : _repository = repository ?? TopicRepository();
  final TopicRepository _repository;

  // ==========================================================================
  // OBSERVABLE STATE VARIABLES
  // ==========================================================================
  final RxList<Topic> topics = <Topic>[].obs;
  final RxList<Topic> featuredTopics = <Topic>[].obs;
  final RxString selectedCategory = 'all'.obs;
  final Rx<ExploreMode> exploreMode = ExploreMode.discover.obs;
  final RxString searchQuery = ''.obs;

  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = true.obs;
  final RxString errorMessage = ''.obs;

  // Pagination cursor
  DocumentSnapshot? _lastDoc;
  static const int _pageSize = 20;

  // Search Debouncer
  Timer? _debounceTimer;

  // ==========================================================================
  // LIFECYCLE
  // ==========================================================================
  @override
  void onInit() {
    super.onInit();
    initialFetch();
  }

  @override
  void onClose() {
    _debounceTimer?.cancel();
    super.onClose();
  }

  // ==========================================================================
  // MAIN QUERY STRATEGY
  // ==========================================================================

  /// Initialize and fetch initial feeds (both curated featured & paginated browse)
  Future<void> initialFetch() async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      // 1. Fetch Featured Curated Strips
      featuredTopics.value = await _repository.fetchFeaturedTopics();

      // 2. Fetch paginated topics
      await loadTopics(reset: true);
    } catch (e) {
      errorMessage.value = FriendlyErrorTranslator.getFriendlyMessage(
        e,
        defaultActionMessage: 'load topic feed',
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Paginated fetch of topics depending on active category, mode, and search state
  Future<void> loadTopics({bool reset = false}) async {
    if (isLoadingMore.value) return;
    if (isLoading.value && !reset) return;

    if (reset) {
      topics.clear();
      _lastDoc = null;
      hasMore.value = true;
    }

    if (!hasMore.value && !reset) return;

    if (reset) {
      isLoading.value = true;
    } else {
      isLoadingMore.value = true;
    }

    try {
      var newTopics = <Topic>[];

      // If search query is present, perform case-insensitive local/filter lookup
      if (searchQuery.isNotEmpty) {
        // Query-driven searching (zero-cost cached scan lookup fallback for MVP)
        final prefix = searchQuery.value.trim();
        newTopics = await _repository.searchTopics(prefix, limit: _pageSize);
        hasMore.value =
            false; // Search results are currently non-paginated for search accuracy
      } else {
        // Standard paginated database retrieval
        if (exploreMode.value == ExploreMode.trending) {
          newTopics = await _repository.fetchTrendingTopics(
            lastDoc: _lastDoc,
            category: selectedCategory.value,
          );
        } else if (exploreMode.value == ExploreMode.yearly) {
          // Yearly trended topics mock-query (pull by category or lower video count fallback)
          newTopics = await _repository.fetchTopics(
            lastDoc: _lastDoc,
            category: selectedCategory.value,
          );
          // Sort or compute yearly activity boost offline
          newTopics.sort((a, b) => b.trendingScore.compareTo(a.trendingScore));
        } else {
          // ExploreMode.discover (default)
          newTopics = await _repository.fetchTopics(
            lastDoc: _lastDoc,
            category: selectedCategory.value,
          );
        }

        if (newTopics.isNotEmpty) {
          // Cache document snapshot reference for next pagination block
          final rawSnapshot = await FirebaseFirestore.instance
              .collection('topics')
              .doc(newTopics.last.id)
              .get();
          if (rawSnapshot.exists) {
            _lastDoc = rawSnapshot;
          }

          if (newTopics.length < _pageSize) {
            hasMore.value = false;
          }
        } else {
          hasMore.value = false;
        }
      }

      // Filter out any duplicates to ensure robust, unique listing
      final existingIds = topics.map((t) => t.id).toSet();
      final uniqueNewTopics = newTopics
          .where((t) => !existingIds.contains(t.id))
          .toList();
      topics.addAll(uniqueNewTopics);
    } catch (e) {
      errorMessage.value = FriendlyErrorTranslator.getFriendlyMessage(
        e,
        defaultActionMessage: 'load topics',
      );
      if (!reset) {
        SnackbarService.error(
          message: FriendlyErrorTranslator.getFriendlyMessage(
            e,
            defaultActionMessage: 'load more topics',
          ),
        );
      }
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  /// Paging handler
  Future<void> loadMoreTopics() async {
    if (!isLoadingMore.value && hasMore.value) {
      await loadTopics();
    }
  }

  // ==========================================================================
  // FILTERS & SELECTIONS
  // ==========================================================================

  /// Filter results by category selection
  void selectCategory(String category) {
    if (selectedCategory.value == category) return;
    selectedCategory.value = category;
    loadTopics(reset: true);
  }

  /// Switch the active explore feed mode
  void setExploreMode(ExploreMode mode) {
    if (exploreMode.value == mode) return;
    exploreMode.value = mode;
    loadTopics(reset: true);
  }

  /// Handle search query updates with 400ms debounce
  void updateSearchQuery(String query) {
    searchQuery.value = query;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      loadTopics(reset: true);
    });
  }

  /// Clear the active search filter
  void clearSearch() {
    searchQuery.value = '';
    loadTopics(reset: true);
  }

  // ==========================================================================
  // DISCOVERY PRELOADING ENGINE
  // ==========================================================================

  /// Preload target topic metadata into details screen controller to bypass empty flashes
  void preloadTopicDetails(Topic topic) {
    debugPrint(
      '🚀 [TopicDiscovery] Preloading details for slug: ${topic.slug}',
    );

    // Check if the topic controller already exists in Memory or instantiate it
    if (Get.isRegistered<TopicController>()) {
      final topicController = Get.find<TopicController>();
      topicController.topic.value = topic;
    } else {
      final topicController = Get.put(TopicController());
      topicController.topic.value = topic;
    }
  }
}

enum ExploreMode {
  discover,
  trending,
  yearly,
}

