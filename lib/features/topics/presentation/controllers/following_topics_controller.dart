import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/feedback/feedback_service.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/data/repositories/topic_repository.dart';

/// GetX controller for the Following Topics page
class FollowingTopicsController extends GetxController {
  final TopicRepository _repository;

  FollowingTopicsController({TopicRepository? repository})
    : _repository = repository ?? TopicRepository();

  // ==========================================================================
  // OBSERVABLE STATE VARIABLES
  // ==========================================================================
  final RxList<Topic> followedTopics = <Topic>[].obs;
  final RxList<Topic> favoriteTopics = <Topic>[].obs;
  final RxString activeTab = 'Following'.obs; // 'Following', 'Favorites'
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  // Search & Filtering State (Matching PlaylistController model)
  final RxString searchQuery = ''.obs;
  final RxString selectedCategory = 'All'.obs;
  final RxBool isSearchExpanded = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchFollowingTopics();
  }

  /// Retrieve all topics followed and liked/favorited by the authenticated user
  Future<void> fetchFollowingTopics() async {
    final userId = AuthService.to.uid;
    if (userId.isEmpty) {
      errorMessage.value = 'Please sign in to view your followed topics.';
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      final results = await Future.wait([
        _repository.fetchFollowedTopics(userId),
        _repository.fetchFavoriteTopics(userId),
      ]);
      followedTopics.value = results[0];
      favoriteTopics.value = results[1];
    } catch (e) {
      errorMessage.value = FriendlyErrorTranslator.getFriendlyMessage(
        e,
        defaultActionMessage: 'fetch followed topics',
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Updates local search query
  void updateSearchQuery(String value) {
    searchQuery.value = value;
  }

  /// Sets active category filter
  void setCategory(String category) {
    selectedCategory.value = category;
  }

  /// Get uniquely derived categories from loaded followed topics for the filter chips
  List<String> get derivedCategories {
    final List<String> cats = ['All'];
    List<Topic> currentList;
    if (activeTab.value == 'Favorites') {
      currentList = favoriteTopics;
    } else {
      currentList = followedTopics;
    }

    for (var topic in currentList) {
      final cat = _capitalize(topic.category);
      if (!cats.contains(cat)) {
        cats.add(cat);
      }
    }
    return cats;
  }

  String _capitalize(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1).toLowerCase();
  }

  /// Toggle follow state and dynamically update local lists to remain reactive
  Future<void> toggleFollowTopic(Topic topic) async {
    final userId = AuthService.to.uid;
    if (userId.isEmpty) {
      SnackbarService.error(message: 'Please sign in to follow topics.');
      return;
    }

    try {
      final isFollowed = await _repository.isTopicFollowed(userId, topic.id);
      bool success;

      if (isFollowed) {
        success = await _repository.unfollowTopic(userId, topic.id);
        if (success) {
          followedTopics.removeWhere((t) => t.id == topic.id);
          SnackbarService.success(
            message: 'You unfollowed "${topic.title}" successfully.',
          );
        }
      } else {
        success = await _repository.followTopic(userId, topic.id);
        if (success) {
          followedTopics.add(topic);
          SnackbarService.success(
            message: 'You followed "${topic.title}" successfully.',
          );
        }
      }
    } catch (e) {
      debugPrint('Error toggling topic followed state: $e');
      SnackbarService.error(
        message: FriendlyErrorTranslator.getFriendlyMessage(
          e,
          defaultActionMessage: 'toggle follow status',
        ),
      );
    }
  }

  /// Helper to check if a specific topic is followed in memory
  bool isTopicFollowed(String topicId) {
    return followedTopics.any((t) => t.id == topicId);
  }
}
