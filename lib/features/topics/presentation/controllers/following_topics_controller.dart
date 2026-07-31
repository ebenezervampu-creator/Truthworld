import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/feedback/feedback_service.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/data/repositories/topic_repository.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// GetX controller for the Following Topics page
class FollowingTopicsController extends GetxController {
  FollowingTopicsController({TopicRepository? repository})
    : _repository = repository ?? TopicRepository();
  final TopicRepository _repository;

  // ==========================================================================
  // OBSERVABLE STATE VARIABLES
  // ==========================================================================
  final RxList<Topic> followedTopics = <Topic>[].obs;
  final RxList<Topic> favoriteTopics = <Topic>[].obs;
  final RxString activeTab = 'Following'.obs; // 'Following', 'Favorites'
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  // Selected topic for filtering (null means 'All' selected)
  final Rxn<Topic> selectedTopic = Rxn<Topic>();

  // Topic videos map: topic.id/slug -> List<Video>
  final RxMap<String, List<Video>> topicVideosMap = <String, List<Video>>{}.obs;
  final RxMap<String, bool> isLoadingVideosMap = <String, bool>{}.obs;

  // Search & Filtering State (Matching PlaylistController model)
  final RxString searchQuery = ''.obs;
  final RxString selectedCategory = 'All'.obs;
  final RxBool isSearchExpanded = false.obs;

  // Topic notification settings map: topicId -> 'all' | 'personalized' | 'none'
  final RxMap<String, String> topicNotificationSettings =
      <String, String>{}.obs;

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

      final uniqueTopicsMap = <String, Topic>{};
      for (final t in results[0]) {
        uniqueTopicsMap[t.id] = t;
      }
      for (final t in results[1]) {
        uniqueTopicsMap[t.id] = t;
      }

      followedTopics.value = uniqueTopicsMap.values.toList();
      favoriteTopics.value = results[1];

      if (followedTopics.isNotEmpty) {
        if (selectedTopic.value == null ||
            !followedTopics.any((t) => t.id == selectedTopic.value?.id)) {
          selectedTopic.value = followedTopics.first;
        }
        for (final topic in followedTopics) {
          fetchVideosForTopic(topic);
        }
      } else {
        selectedTopic.value = null;
      }
    } catch (e) {
      errorMessage.value = FriendlyErrorTranslator.getFriendlyMessage(
        e,
        defaultActionMessage: 'fetch followed topics',
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Fetch videos associated with a specific topic
  Future<void> fetchVideosForTopic(Topic topic) async {
    final key = topic.id;
    if (topicVideosMap.containsKey(key) && isLoadingVideosMap[key] != true) {
      return;
    }

    isLoadingVideosMap[key] = true;
    try {
      var videos = await _repository.getVideosByTopic(topic.slug);
      if (videos.isEmpty && topic.id != topic.slug) {
        videos = await _repository.getVideosByTopic(topic.id);
      }
      topicVideosMap[key] = videos;
    } catch (e) {
      debugPrint('Error fetching videos for topic ${topic.title}: $e');
      topicVideosMap[key] = [];
    } finally {
      isLoadingVideosMap[key] = false;
    }
  }

  /// Select a topic pill
  void selectTopic(Topic? topic) {
    selectedTopic.value = topic;
    if (topic != null) {
      fetchVideosForTopic(topic);
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
    final cats = <String>['All'];
    for (final topic in followedTopics) {
      final cat = _capitalize(topic.category);
      if (cat.isNotEmpty && !cats.contains(cat)) {
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
          if (selectedTopic.value?.id == topic.id) {
            selectedTopic.value = followedTopics.isNotEmpty
                ? followedTopics.first
                : null;
          }
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
          fetchVideosForTopic(topic);
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

  /// Fetch notification setting for a topic
  Future<String> fetchTopicNotificationSetting(String topicId) async {
    final userId = AuthService.to.uid;
    if (userId.isEmpty) return 'all';

    if (topicNotificationSettings.containsKey(topicId)) {
      return topicNotificationSettings[topicId]!;
    }

    final setting = await _repository.getTopicNotificationSetting(
      userId,
      topicId,
    );
    topicNotificationSettings[topicId] = setting;
    return setting;
  }

  /// Update notification setting for a topic ('all' | 'personalized' | 'none')
  Future<void> updateTopicNotificationSetting(
    String topicId,
    String setting,
  ) async {
    final userId = AuthService.to.uid;
    if (userId.isEmpty) {
      SnackbarService.error(
        message: 'Please sign in to update notification settings.',
      );
      return;
    }

    try {
      topicNotificationSettings[topicId] = setting;
      await _repository.updateTopicNotificationSetting(
        userId,
        topicId,
        setting,
      );

      final label = setting == 'all'
          ? 'All notifications'
          : (setting == 'personalized'
                ? 'Personalized notifications'
                : 'Notifications turned off');
      SnackbarService.success(
        message: 'Notification preference updated to "$label".',
      );
    } catch (e) {
      debugPrint('Error updating topic notification setting: $e');
      SnackbarService.error(message: 'Failed to update notification settings.');
    }
  }
}
